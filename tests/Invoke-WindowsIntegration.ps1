#requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

# Deze test wijzigt taken en ACL's, uitsluitend op de wegwerpmachine van GitHub Actions.
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP) {
    throw 'Deze integratietest mag uitsluitend op GitHub Actions worden uitgevoerd.'
}
if (Get-ScheduledTask -TaskName 'LeenlaptopSchoonmaak' -ErrorAction SilentlyContinue) {
    throw 'Onverwachte bestaande utility-taak; integratietest gestopt.'
}
$shortcutPath = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Leenlaptop Opschonen.lnk'
if (Test-Path -LiteralPath $shortcutPath) { throw 'Onverwachte bestaande utility-snelkoppeling; integratietest gestopt.' }

$source = Split-Path $PSScriptRoot
$caseRoot = Join-Path $env:RUNNER_TEMP ('leenlaptop-integration-' + [guid]::NewGuid().ToString('N'))
$installPath = Join-Path $caseRoot 'LeenlaptopSchoonmaak'
$configPath = Join-Path $caseRoot 'config.json'
New-Item $caseRoot -ItemType Directory | Out-Null
Import-Module (Join-Path $source 'LeenlaptopSchoonmaak.psm1') -Force
$config = & (Get-Module LeenlaptopSchoonmaak) { Get-DefaultConfiguration }
foreach ($key in @($config.Keys)) {
    if ($key -like 'Enable*') { $config[$key] = $false }
}
$config.EnableStartupTask = $true
$config.EnableShortcut = $true
$config.RunAtLogon = $false
$config | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
$account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value

try {
    $result = Invoke-LeenlaptopUtility -Action Install -SourcePath $source -InstallPath $installPath -ConfigPath $configPath -TargetUser $account
    if ($result.ExitCode -ne 0) { throw 'Eerste installatie is niet geslaagd.' }
    $task = Get-ScheduledTask -TaskName 'LeenlaptopSchoonmaak'
    if (@($task.Triggers | Where-Object { $_ }).Count -ne 0) { throw 'Er is onbedoeld een automatische trigger ingesteld.' }
    if ($task.Principal.LogonType -ne 'Interactive') { throw 'Taak gebruikt geen interactieve gebruikerscontext.' }
    if ($task.Actions.Arguments -notmatch '\s-Cleanup\s') { throw 'Taak verwijst niet naar de cleanup-modus.' }
    $shell = New-Object -ComObject WScript.Shell
    $link = $null
    try {
        $link = $shell.CreateShortcut($shortcutPath)
        if ($link.Arguments -ne '/Run /TN "LeenlaptopSchoonmaak"') { throw 'Snelkoppeling start niet de geconfigureerde taak.' }
    } finally {
        foreach ($instance in @($link, $shell)) {
            if ($instance) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($instance) }
        }
    }
    $service = New-Object -ComObject 'Schedule.Service'
    $folder = $null; $registeredTask = $null
    try {
        $service.Connect()
        $folder = $service.GetFolder('\')
        $registeredTask = $folder.GetTask('LeenlaptopSchoonmaak')
        $descriptor = New-Object Security.AccessControl.RawSecurityDescriptor($registeredTask.GetSecurityDescriptor(4))
        $targetAce = @($descriptor.DiscretionaryAcl | Where-Object { $_.SecurityIdentifier.Value -eq $sid })
        if ($targetAce.Count -ne 1) { throw 'Taak-DACL bevat geen unieke doelaccountregel.' }
        $mask = $targetAce[0].AccessMask
        if (-not (($mask -band 0x20000000) -or ($mask -band 0x20)) -or ($mask -band 0x500D0116)) {
            throw 'Taak-DACL geeft het doelaccount geen correcte lees/startrechten.'
        }
    } finally {
        foreach ($instance in @($registeredTask, $folder, $service)) {
            if ($instance) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($instance) }
        }
    }
    foreach ($name in @('LeenlaptopSchoonmaak.ps1', 'LeenlaptopSchoonmaak.psm1', 'config.json', 'manifest.json')) {
        $acl = Get-Acl -LiteralPath (Join-Path $installPath $name)
        $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object { $_.IdentityReference.Value -eq $sid })
        if ($rules.Count -ne 1 -or ($rules[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::WriteData)) {
            throw "Doelaccount heeft onjuiste programmarechten voor $name."
        }
    }
    $stateAcl = Get-Acl -LiteralPath (Join-Path $installPath 'state')
    $stateRule = @($stateAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object { $_.IdentityReference.Value -eq $sid })
    if ($stateRule.Count -ne 1 -or -not ($stateRule[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::WriteData)) {
        throw 'Doelaccount kan de statusmap niet beschrijven.'
    }

    # Geen cleanup-stappen: controleert alleen de echte runner, lock en rapportage.
    $result = Invoke-LeenlaptopUtility -Action Cleanup -SourcePath $source -InstallPath $installPath
    if ($result.ExitCode -ne 0 -or $result.Results[0].Status -ne 'Skipped') { throw 'Lege cleanup is niet correct afgehandeld.' }
    $result = Invoke-LeenlaptopUtility -Action Check -SourcePath $source -InstallPath $installPath
    if ($result.ExitCode -ne 0) { throw 'Geinstalleerd pakket doorstaat de controle niet.' }
    $entry = Join-Path $installPath 'LeenlaptopSchoonmaak.ps1'
    $powershellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $json = & $powershellPath -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $entry -PrintConfig -InstallPath $installPath
    if ($LASTEXITCODE -ne 0) { throw 'Geinstalleerde CLI kan geen configuratie exporteren.' }
    $exported = ($json -join [Environment]::NewLine) | ConvertFrom-Json
    if ($exported.TargetUserSid -ne $sid -or $exported.EnableBrowserCleanup) { throw 'CLI leest niet de geinstalleerde configuratie.' }

    $saved = Get-Content (Join-Path $installPath 'config.json') -Raw | ConvertFrom-Json
    $saved.DownloadsMaxAgeDays = 19
    $saved | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $installPath 'config.json') -Encoding UTF8
    $result = Invoke-LeenlaptopUtility -Action Install -SourcePath $source -InstallPath $installPath -TargetUser $account
    if ($result.ExitCode -ne 0 -or $result.Config.DownloadsMaxAgeDays -ne 19) { throw 'Update bewaart bestaande configuratie niet.' }

    # Test het vervangen van een handmatige taak door een logon-taak en weer terug.
    $saved.RunAtLogon = $true
    $saved | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
    $result = Invoke-LeenlaptopUtility -Action Install -SourcePath $source -InstallPath $installPath -ConfigPath $configPath -TargetUser $account
    if ($result.ExitCode -ne 0 -or @(Get-ScheduledTask -TaskName 'LeenlaptopSchoonmaak' | Select-Object -ExpandProperty Triggers).Count -ne 1) {
        throw 'Logon-trigger is niet geregistreerd.'
    }
    $saved.EnableStartupTask = $false
    $saved.RunAtLogon = $false
    $saved | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
    $result = Invoke-LeenlaptopUtility -Action Install -SourcePath $source -InstallPath $installPath -ConfigPath $configPath -TargetUser $account
    if ($result.ExitCode -ne 0 -or (Get-ScheduledTask -TaskName 'LeenlaptopSchoonmaak' -ErrorAction SilentlyContinue)) {
        throw 'Uitgeschakelde taak is niet verwijderd.'
    }
    Write-Output 'Windows integration: install, ACLs, task permissions, shortcut, manifest, CLI, reports, update, triggers and task removal OK.'
} finally {
    if (Get-ScheduledTask -TaskName 'LeenlaptopSchoonmaak' -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName 'LeenlaptopSchoonmaak' -Confirm:$false
    }
    if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force }
    # Testbestanden blijven in RUNNER_TEMP; GitHub verwijdert de volledige wegwerpmachine.
}
