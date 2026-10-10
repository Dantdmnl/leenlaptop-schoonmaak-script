#requires -Version 5.1
Set-StrictMode -Version 2.0
$script:UtilityVersion = '1.7.0-rc.1'
$script:Deadline = $null
$script:TaskName = 'LeenlaptopSchoonmaak'
$script:PackageFiles = @('LeenlaptopSchoonmaak.ps1', 'LeenlaptopSchoonmaak.psm1', 'config.example.json', 'WlanProfiles.cs')

function Get-DefaultConfiguration {
    [ordered]@{
        SchemaVersion = 1; TargetUserSid = ''; EnableShortcut = $true
        EnableStartupTask = $true; RunAtLogon = $false
        EnableBrowserCleanup = $true; BrowserList = @('msedge', 'firefox', 'chrome')
        EnableWiFiCleanup = $true; AllowedWiFi = @(); EnableTempCleanup = $true
        EnableDownloadsCleanup = $true; DownloadsMaxAgeDays = 7
        EnableDocumentsCleanup = $false; DocumentsMaxAgeDays = 30
        EnablePicturesCleanup = $false; PicturesMaxAgeDays = 30
        EnableVideosCleanup = $false; VideosMaxAgeDays = 30
        EnableMusicCleanup = $false; MusicMaxAgeDays = 30
        EnableFirewallReset = $true; EnableBackupCleanup = $true
        MaxBackupCount = 5; MaxLogSizeMB = 5; LogRetentionDays = 30
        MaxRetries = 3; MaxExecutionMinutes = 5
    }
}

function Test-UtilityConfiguration {
    param([System.Collections.IDictionary]$Config)
    $defaults = Get-DefaultConfiguration
    foreach ($key in $Config.Keys) {
        if (-not $defaults.Contains($key)) { throw "Onbekende configuratiesleutel: $key" }
    }
    foreach ($key in $defaults.Keys) {
        if (-not $Config.Contains($key)) { throw "Configuratiesleutel ontbreekt: $key" }
        $value = $Config[$key]
        if ($defaults[$key] -is [bool] -and $value -isnot [bool]) { throw "$key moet een JSON-boolean zijn." }
        if ($defaults[$key] -is [int]) {
            if ($value -isnot [int] -and $value -isnot [long]) { throw "$key moet een geheel getal zijn." }
            $minimum = if ($key -eq 'MaxBackupCount') { 0 } else { 1 }
            if ($value -lt $minimum -or $value -gt 100000) { throw "Ongeldige waarde voor $key." }
        }
    }
    if ($Config.SchemaVersion -ne 1) { throw 'Deze configuratieversie wordt niet ondersteund.' }
    if ($Config.TargetUserSid -isnot [string] -or ($Config.TargetUserSid -and $Config.TargetUserSid -notmatch '^S-1-(5-21|12-1)-\d+-\d+-\d+-\d+$')) {
        throw 'TargetUserSid moet leeg of een gebruikers-SID zijn.'
    }
    foreach ($key in @('BrowserList', 'AllowedWiFi')) {
        if ($Config[$key] -isnot [array]) { throw "$key moet een JSON-array zijn." }
        foreach ($item in $Config[$key]) {
            if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { throw "$key bevat een ongeldige waarde." }
        }
    }
    foreach ($browser in $Config.BrowserList) {
        if ($browser -notin @('msedge', 'chrome', 'firefox')) { throw "Niet ondersteunde browser: $browser" }
    }
}

function Import-LegacyConfiguration {
    param([string]$Path, [ref]$LegacyTaskName)
    $config = Get-DefaultConfiguration
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Oud script bevat syntaxfouten; migratie gestopt.' }
    $assignments = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)
    $seen = @{}
    foreach ($assignment in $assignments) {
        $left = $assignment.Left
        if ($left -is [System.Management.Automation.Language.ConvertExpressionAst]) { $left = $left.Child }
        if ($left -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        $name = $left.VariablePath.UserPath
        if ((-not $config.Contains($name) -and $name -ne 'TaskName') -or $seen.ContainsKey($name)) { continue }
        try {
            $right = $assignment.Right
            if ($right -is [System.Management.Automation.Language.CommandExpressionAst] -and $right.Redirections.Count -eq 0) {
                $right = $right.Expression
            }
            $value = $right.SafeGetValue()
            if ($name -eq 'TaskName') {
                if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or $value -match '[*?\[\]\\/]') { throw 'Ongeldige oude taaknaam.' }
                if ($LegacyTaskName) { $LegacyTaskName.Value = $value }
            } else { $config[$name] = $value }
        }
        catch { throw "Instelling $name kan niet veilig worden gemigreerd. Gebruik een expliciet JSON-configuratiebestand." }
        $seen[$name] = $true
    }
    # Een oude installatie gaf geen expliciete toestemming voor de nieuwe automatische modus.
    $config.RunAtLogon = $false
    Test-UtilityConfiguration $config
    return $config
}

function Read-UtilityConfiguration {
    param([string]$SourcePath, [string]$InstallPath, [string]$ConfigPath, [string]$LegacyProfilePath)
    $candidates = @()
    if ($ConfigPath) { $candidates = @($ConfigPath) }
    else { $candidates = @((Join-Path $InstallPath 'config.json'), (Join-Path $SourcePath 'config.json')) }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $inputConfig = Get-Content -LiteralPath $candidate -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($inputConfig -isnot [pscustomobject]) { throw 'Configuratie moet een JSON-object zijn.' }
        $config = Get-DefaultConfiguration
        foreach ($property in $inputConfig.PSObject.Properties) {
            if (-not $config.Contains($property.Name)) { throw "Onbekende configuratiesleutel: $($property.Name)" }
            $config[$property.Name] = $property.Value
        }
        Test-UtilityConfiguration $config
        return @{ Config = $config; Source = $candidate; Legacy = $false }
    }
    if ($ConfigPath) { throw 'Het opgegeven configuratiebestand bestaat niet.' }
    $legacyCandidates = @((Join-Path $InstallPath 'LeenlaptopSchoonmaak.ps1'), (Join-Path $InstallPath 'opstart-script.ps1'))
    if ($LegacyProfilePath) { $legacyCandidates += Join-Path $LegacyProfilePath 'AppData\Local\HiddenScripts\opstart-script.ps1' }
    elseif ($env:LOCALAPPDATA) { $legacyCandidates += Join-Path $env:LOCALAPPDATA 'HiddenScripts\opstart-script.ps1' }
    foreach ($candidate in $legacyCandidates) {
        if ((Test-Path -LiteralPath $candidate) -and -not (Test-Path -LiteralPath (Join-Path (Split-Path $candidate) 'LeenlaptopSchoonmaak.psm1'))) {
            $legacyTaskName = ''
            $legacyConfig = Import-LegacyConfiguration $candidate ([ref]$legacyTaskName)
            return @{ Config = $legacyConfig; Source = $candidate; Legacy = $true; LegacyTaskName = $legacyTaskName }
        }
    }
    return @{ Config = (Get-DefaultConfiguration); Source = 'defaults'; Legacy = $false }
}

function Get-CurrentUserSid {
    [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-TargetUser {
    param([string]$TargetUser, [string]$Sid)
    if ($TargetUser) {
        $account = New-Object Security.Principal.NTAccount($TargetUser)
        $Sid = $account.Translate([Security.Principal.SecurityIdentifier]).Value
    }
    if (-not $Sid) { throw 'Geef bij installatie een doelaccount op met -TargetUser.' }
    $identity = New-Object Security.Principal.SecurityIdentifier($Sid)
    $accountName = $identity.Translate([Security.Principal.NTAccount]).Value
    $targetProfileRecord = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$Sid" -ErrorAction Stop
    $profilePath = [Environment]::ExpandEnvironmentVariables($targetProfileRecord.ProfileImagePath)
    if (-not (Test-Path -LiteralPath $profilePath -PathType Container)) { throw 'Doelaccount heeft geen beschikbaar lokaal profiel. Log eerst eenmaal in.' }
    return @{ Sid = $Sid; Account = $accountName; ProfilePath = $profilePath }
}

function New-StepResult {
    param([string]$Name, [ValidateSet('Success', 'Partial', 'Failed', 'Skipped', 'Planned')][string]$Status,
        [int]$Removed = 0, [int]$Failed = 0, [string]$Detail = '')
    [pscustomobject]@{ Name = $Name; Status = $Status; Removed = $Removed; Failed = $Failed; Detail = $Detail }
}

function Get-ResultExitCode {
    param([object[]]$Results)
    if (@($Results | Where-Object Status -eq 'Failed').Count) { return 1 }
    if (@($Results | Where-Object Status -eq 'Partial').Count) { return 2 }
    $plannedCount = @($Results | Where-Object Status -eq 'Planned').Count
    if ($plannedCount -gt 0 -and $plannedCount -lt $Results.Count) { return 2 }
    return 0
}

function Assert-TimeRemaining {
    if ($script:Deadline -and [DateTime]::UtcNow -ge $script:Deadline) { throw 'Maximale uitvoeringstijd overschreden.' }
}

function Assert-SafeRoot {
    param([string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if ($fullPath -eq [IO.Path]::GetPathRoot($fullPath).TrimEnd('\', '/')) { throw 'Een schijfhoofdmap is geen toegestane opschoonlocatie.' }
    $existingPath = $fullPath
    while (-not (Test-Path -LiteralPath $existingPath)) {
        $existingPath = [IO.Path]::GetDirectoryName($existingPath)
        if (-not $existingPath) { throw 'Geen geldige bestaande bovenliggende map gevonden.' }
    }
    $item = Get-Item -LiteralPath $existingPath -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw 'Opschoonlocatie is geen map.' }
    while ($item) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Opschoonlocatie loopt via een junction of symbolische link.' }
        $item = $item.Parent
    }
}

function Get-SafeTree {
    param([string]$Path)
    Assert-SafeRoot $Path
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push([IO.Path]::GetFullPath($Path))
    while ($pending.Count) {
        Assert-TimeRemaining
        $folder = $pending.Pop()
        Assert-SafeRoot $folder
        foreach ($item in Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $item; continue }
            $item
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}

function Assert-UserDataPath {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $profileRoot = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') + '\'
    if (-not $full.StartsWith($profileRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Gebruikersmap ligt buiten het huidige lokale profiel; opschoning geweigerd.'
    }
    foreach ($cloud in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
        if (-not $cloud) { continue }
        $cloudRoot = [IO.Path]::GetFullPath($cloud).TrimEnd('\')
        if ($full -eq $cloudRoot -or $full.StartsWith($cloudRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Gebruikersmap ligt in OneDrive; opschoning geweigerd.'
        }
    }
    Assert-SafeRoot $full
}

function Remove-UtilityFolderItems {
    param([string]$Path, [string]$Name, [int]$MaxAgeDays = 0)
    $removed = 0; $failed = 0
    $cutoff = [DateTime]::Now.AddDays(-$MaxAgeDays)
    try { $items = @(Get-SafeTree $Path) }
    catch { return New-StepResult $Name 'Failed' -Failed 1 -Detail 'Map kon niet volledig worden gelezen; niets verwijderd.' }
    $failed = @($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count
    $items = @($items | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
    foreach ($item in $items | Where-Object { -not $_.PSIsContainer }) {
        Assert-TimeRemaining
        if ($MaxAgeDays -gt 0 -and $item.LastWriteTime -ge $cutoff) { continue }
        try {
            # Controleer de bovenliggende route opnieuw voordat een bestand wordt verwijderd.
            Assert-SafeRoot $item.DirectoryName
            $current = Get-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { $failed++; continue }
            if ($MaxAgeDays -gt 0 -and $current.LastWriteTime -ge $cutoff) { continue }
            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            $removed++
        } catch { $failed++ }
    }
    foreach ($item in $items | Where-Object PSIsContainer | Sort-Object { $_.FullName.Length } -Descending) {
        Assert-TimeRemaining
        if ($MaxAgeDays -gt 0 -and $item.LastWriteTime -ge $cutoff) { continue }
        try {
            Assert-SafeRoot $item.FullName
            if (@(Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop).Count -eq 0) {
                Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                $removed++
            }
        } catch { $failed++ }
    }
    $status = if ($failed) { 'Partial' } else { 'Success' }
    New-StepResult $Name $status -Removed $removed -Failed $failed
}

function Clear-UtilityBrowser {
    param([string]$Browser, [int]$MaxRetries)
    $currentSid = Get-CurrentUserSid
    $root = switch ($Browser) {
        'msedge' { Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data' }
        'chrome' { Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data' }
        'firefox' { Join-Path $env:APPDATA 'Mozilla\Firefox' }
    }
    Assert-UserDataPath $root
    # Beperk procesbeheer tot het doelaccount; andere accounts blijven ongemoeid.
    foreach ($process in Get-CimInstance Win32_Process -Filter "Name = '$Browser.exe'" -ErrorAction Stop) {
        Assert-TimeRemaining
        $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid -ErrorAction Stop
        if ($owner.ReturnValue -ne 0) { throw 'Browserproces heeft geen controleerbare eigenaar.' }
        if ($owner.Sid -ne $currentSid) { continue }
        Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
        for ($attempt = 0; $attempt -lt $MaxRetries; $attempt++) {
            Assert-TimeRemaining
            if (-not (Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue)) { break }
            Start-Sleep -Milliseconds 300
        }
        if (Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue) { throw 'Browser kon niet worden afgesloten.' }
    }
    # Wis de inhoud van de volledige lokale browseropslag, inclusief aangepaste profielen.
    $result = Remove-UtilityFolderItems -Path $root -Name $Browser
    if ($Browser -eq 'firefox') {
        $cachePath = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox'
        Assert-UserDataPath $cachePath
        $cache = Remove-UtilityFolderItems -Path $cachePath -Name 'firefox-cache'
        $result.Removed += $cache.Removed; $result.Failed += $cache.Failed
        if ($cache.Status -eq 'Failed') { $result.Status = 'Failed' }
        elseif ($result.Failed) { $result.Status = 'Partial' }
    }
    return $result
}

function Get-WiFiProfileNames {
    if (-not ('Leenlaptop.WlanProfiles' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'WlanProfiles.cs') -ErrorAction Stop }
    [Leenlaptop.WlanProfiles]::GetNames()
}

function Remove-WiFiProfileName {
    param([string]$Name)
    [Leenlaptop.WlanProfiles]::DeleteName($Name)
}

function ConvertTo-NativeArgument {
    param([string]$Value)
    # Windows command-line escaping: verdubbel backslashes voor quotes en aan het einde.
    '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function Invoke-UtilityNative {
    param([string]$FilePath, [string[]]$Arguments)
    Assert-TimeRemaining
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $FilePath
    $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        while (-not $process.WaitForExit(200)) {
            try { Assert-TimeRemaining }
            catch { $process.Kill(); throw }
        }
        # Wacht alleen na procesexit op de readers, zodat de uitvoerbuffers worden afgevoerd.
        [void]$stdout.GetAwaiter().GetResult()
        [void]$stderr.GetAwaiter().GetResult()
        return $process.ExitCode
    } finally { $process.Dispose() }
}

function Clear-UtilityWiFi {
    param([string[]]$AllowedWiFi)
    $removed = 0; $failed = 0
    foreach ($name in Get-WiFiProfileNames) {
        Assert-TimeRemaining
        if ($AllowedWiFi -ccontains $name) { continue }
        try { $removed += Remove-WiFiProfileName $name }
        catch { $failed++ }
    }
    $status = if ($failed) { 'Partial' } else { 'Success' }
    New-StepResult 'Wi-Fi' $status -Removed $removed -Failed $failed
}

function Get-CleanupPlan {
    param([System.Collections.IDictionary]$Config)
    if ($Config.EnableBrowserCleanup) {
        foreach ($browser in $Config.BrowserList) {
            @{ Name = $browser; Kind = 'Browser'; Browser = $browser; Admin = $false }
        }
    }
    if ($Config.EnableTempCleanup) { @{ Name = 'Temp'; Kind = 'Folder'; Path = $env:TEMP; Age = 0; Admin = $false } }
    if ($Config.EnableDownloadsCleanup) {
        $downloads = Join-Path $env:USERPROFILE 'Downloads'
        $shellFolders = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue
        $downloadsId = '{374DE290-123F-4565-9164-39C4925E467B}'
        if ($shellFolders -and $shellFolders.PSObject.Properties[$downloadsId]) {
            $downloads = [Environment]::ExpandEnvironmentVariables($shellFolders.$downloadsId)
        }
        @{ Name = 'Downloads'; Kind = 'Folder'; Path = $downloads; Age = $Config.DownloadsMaxAgeDays; Admin = $false }
    }
    foreach ($folder in @(
        @{ Name = 'Documents'; Special = 'MyDocuments' }, @{ Name = 'Pictures'; Special = 'MyPictures' },
        @{ Name = 'Videos'; Special = 'MyVideos' }, @{ Name = 'Music'; Special = 'MyMusic' }
    )) {
        if ($Config[('Enable{0}Cleanup' -f $folder.Name)]) {
            $path = [Environment]::GetFolderPath([Environment+SpecialFolder]$folder.Special)
            if (-not $path) { throw "Gebruikersmap $($folder.Name) kon niet worden bepaald." }
            @{ Name = $folder.Name; Kind = 'Folder'; Path = $path; Age = $Config[('{0}MaxAgeDays' -f $folder.Name)]; Admin = $false }
        }
    }
    if ($Config.EnableWiFiCleanup) { @{ Name = 'Wi-Fi'; Kind = 'WiFi'; Admin = $true } }
    if ($Config.EnableFirewallReset) { @{ Name = 'Firewall'; Kind = 'Firewall'; Admin = $true } }
}

function Invoke-CleanupStep {
    param([hashtable]$Step, [System.Collections.IDictionary]$Config)
    Assert-TimeRemaining
    try {
        if ($Step.Admin -and -not (Test-Administrator)) {
            return New-StepResult $Step.Name 'Partial' -Failed 1 -Detail 'Administratorrechten vereist.'
        }
        switch ($Step.Kind) {
            'Folder' { Assert-UserDataPath $Step.Path; return Remove-UtilityFolderItems $Step.Path $Step.Name $Step.Age }
            'Browser' { return Clear-UtilityBrowser $Step.Browser $Config.MaxRetries }
            'WiFi' { return Clear-UtilityWiFi $Config.AllowedWiFi }
            'Firewall' {
                $code = Invoke-UtilityNative "$env:SystemRoot\System32\netsh.exe" @('advfirewall', 'reset')
                if ($code -ne 0) { throw 'Firewallreset mislukt.' }
                return New-StepResult $Step.Name 'Success'
            }
        }
    } catch {
        if ($script:Deadline -and [DateTime]::UtcNow -ge $script:Deadline) { throw }
        return New-StepResult $Step.Name 'Failed' -Failed 1 -Detail 'Actie mislukt; controleer rechten, services en vergrendelde bestanden.'
    }
}

function Enter-UtilityLock {
    param([string]$InstallPath)
    $state = Join-Path $InstallPath 'state'
    Assert-SafeRoot $state
    [IO.Directory]::CreateDirectory($state) | Out-Null
    try { return [IO.File]::Open((Join-Path $state 'run.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { throw 'Utility is al actief of de locklocatie is niet schrijfbaar.' }
}

function Set-UtilityPermissions {
    param([string]$Path, [string]$TargetSid, [switch]$Writable, [switch]$AdminOnly)
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    $sids = @('S-1-5-18', 'S-1-5-32-544')
    if (-not $AdminOnly) { $sids += $TargetSid }
    foreach ($sid in $sids | Select-Object -Unique) {
        $rights = 'FullControl'
        if ($sid -eq $TargetSid) { $rights = if ($Writable) { 'Modify' } else { 'ReadAndExecute' } }
        $identity = New-Object Security.Principal.SecurityIdentifier($sid)
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity, $rights, 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Set-UtilityFilePermissions {
    param([string]$Path, [string]$TargetSid)
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach ($sid in @('S-1-5-18', 'S-1-5-32-544', $TargetSid) | Select-Object -Unique) {
        $rights = if ($sid -eq $TargetSid) { 'ReadAndExecute' } else { 'FullControl' }
        $identity = New-Object Security.Principal.SecurityIdentifier($sid)
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($identity, $rights, 'Allow')))
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Set-UtilityTask {
    param([string]$InstallPath, [System.Collections.IDictionary]$Config)
    if (-not $Config.EnableStartupTask) {
        if (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction Stop
        }
        return
    }
    $exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $path = Join-Path $InstallPath 'LeenlaptopSchoonmaak.ps1'
    $action = New-ScheduledTaskAction -Execute $exe -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$path`" -Cleanup -InstallPath `"$InstallPath`""
    $principal = New-ScheduledTaskPrincipal -UserId $Config.TargetUserSid -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes $Config.MaxExecutionMinutes)
    $arguments = @{ TaskName = $script:TaskName; Action = $action; Principal = $principal; Settings = $settings; Force = $true; ErrorAction = 'Stop' }
    if ($Config.RunAtLogon) { $arguments.Trigger = New-ScheduledTaskTrigger -AtLogOn -User $Config.TargetUserSid }
    Register-ScheduledTask @arguments | Out-Null
    Set-UtilityTaskPermissions $Config.TargetUserSid
    $task = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction Stop
    $principalSid = $task.Principal.UserId
    if ($principalSid -notmatch '^S-1-') {
        $principalSid = (New-Object Security.Principal.NTAccount($principalSid)).Translate([Security.Principal.SecurityIdentifier]).Value
    }
    if ($task.Actions.Arguments -notcontains $action.Arguments -or $principalSid -ne $Config.TargetUserSid) {
        throw 'Verificatie van de nieuwe geplande taak mislukt.'
    }
}

function Set-UtilityTaskPermissions {
    param([string]$TargetSid, [string]$SecurityDescriptor)
    $service = New-Object -ComObject 'Schedule.Service'
    $folder = $null; $task = $null
    try {
        $service.Connect()
        $folder = $service.GetFolder('\')
        $task = $folder.GetTask($script:TaskName)
        # Het doelaccount mag de taak lezen en starten, maar niet wijzigen.
        if (-not $SecurityDescriptor) { $SecurityDescriptor = "D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGX;;;$TargetSid)" }
        $task.SetSecurityDescriptor($SecurityDescriptor, 0x10)
    } finally {
        foreach ($instance in @($task, $folder, $service)) {
            if ($instance) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($instance) }
        }
    }
}

function Get-UtilityTaskSecurityDescriptor {
    $service = New-Object -ComObject 'Schedule.Service'
    $folder = $null; $task = $null
    try {
        $service.Connect()
        $folder = $service.GetFolder('\')
        $task = $folder.GetTask($script:TaskName)
        return $task.GetSecurityDescriptor(4)
    } finally {
        foreach ($instance in @($task, $folder, $service)) {
            if ($instance) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($instance) }
        }
    }
}

function Get-UtilityShortcutPath {
    Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Leenlaptop Opschonen.lnk'
}

function Set-UtilityShortcut {
    param([string]$InstallPath, [System.Collections.IDictionary]$Config)
    # Public Desktop vermijdt het raden van omgeleide bureaubladen vanuit een beheeraccount.
    $path = Get-UtilityShortcutPath
    if (-not $Config.EnableShortcut) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction Stop }
        return
    }
    $shell = New-Object -ComObject WScript.Shell
    try {
        $link = $shell.CreateShortcut($path)
        if ($Config.EnableStartupTask) {
            $link.TargetPath = "$env:SystemRoot\System32\schtasks.exe"
            $link.Arguments = '/Run /TN "LeenlaptopSchoonmaak"'
        } else {
            $link.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
            $entry = Join-Path $InstallPath 'LeenlaptopSchoonmaak.ps1'
            $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$entry`" -Cleanup -InstallPath `"$InstallPath`""
        }
        $link.WorkingDirectory = $InstallPath
        $link.IconLocation = 'shell32.dll,31'
        $link.Save()
    } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
}

function Copy-VerifiedFile {
    param([string]$Source, [string]$Destination)
    Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
    if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256 -ErrorAction Stop).Hash -ne
        (Get-FileHash -LiteralPath $Destination -Algorithm SHA256 -ErrorAction Stop).Hash) {
        throw 'Bestandsverificatie mislukt; installatie gestopt.'
    }
}

function Test-InstalledPackage {
    param([string]$InstallPath)
    $manifestPath = Join-Path $InstallPath 'manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($manifest.Version -ne $script:UtilityVersion) { throw 'Geinstalleerde pakketversie wijkt af.' }
    foreach ($name in $script:PackageFiles) {
        $property = $manifest.Hashes.PSObject.Properties[$name]
        if (-not $property -or (Get-FileHash -LiteralPath (Join-Path $InstallPath $name) -Algorithm SHA256 -ErrorAction Stop).Hash -ne $property.Value) {
            throw 'Geinstalleerd pakket is onvolledig of gewijzigd. Installeer opnieuw vanuit een releasearchief.'
        }
    }
}

function Install-UtilityPackage {
    param([string]$SourcePath, [string]$InstallPath, [System.Collections.IDictionary]$Config, [string]$LegacyTaskName)
    Assert-SafeRoot $InstallPath
    if ([IO.Path]::GetFileName([IO.Path]::GetFullPath($InstallPath).TrimEnd('\')) -ne 'LeenlaptopSchoonmaak') {
        throw 'InstallPath moet eindigen op een afzonderlijke map LeenlaptopSchoonmaak.'
    }
    foreach ($name in $script:PackageFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $SourcePath $name) -PathType Leaf)) { throw "Releasebestand ontbreekt: $name" }
    }
    if ([IO.Path]::GetFullPath($SourcePath).TrimEnd('\') -eq [IO.Path]::GetFullPath($InstallPath).TrimEnd('\')) {
        throw 'Installeer een update vanuit een afzonderlijke uitgepakte releasemap.'
    }
    $originalAcl = $null; $originalStateAcl = $null
    if (Test-Path -LiteralPath $InstallPath) { $originalAcl = Get-Acl -LiteralPath $InstallPath -ErrorAction Stop }
    $state = Join-Path $InstallPath 'state'
    if (Test-Path -LiteralPath $state) {
        Assert-SafeRoot $state
        $originalStateAcl = Get-Acl -LiteralPath $state -ErrorAction Stop
    }
    [IO.Directory]::CreateDirectory($InstallPath) | Out-Null
    [IO.Directory]::CreateDirectory($state) | Out-Null
    $lock = Enter-UtilityLock $InstallPath
    $backup = Join-Path $InstallPath ('backups\' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fffffff'))
    $stage = Join-Path $InstallPath ('stage_' + [guid]::NewGuid().ToString('N'))
    $names = @($script:PackageFiles) + @('config.json', 'version.txt', 'manifest.json', 'opstart-script.ps1')
    $previous = @(); $fileAcls = @{}; $taskXml = $null; $taskSecurity = $null; $deployStarted = $false
    $shortcutPath = ''; $shortcutExisted = $false
    try {
        $shortcutPath = Get-UtilityShortcutPath
        $shortcutExisted = Test-Path -LiteralPath $shortcutPath
        Set-UtilityPermissions $InstallPath $Config.TargetUserSid
        Set-UtilityPermissions $state $Config.TargetUserSid -Writable
        Assert-SafeRoot (Join-Path $InstallPath 'backups')
        [IO.Directory]::CreateDirectory((Join-Path $InstallPath 'backups')) | Out-Null
        Set-UtilityPermissions (Join-Path $InstallPath 'backups') $Config.TargetUserSid -AdminOnly
        [IO.Directory]::CreateDirectory($backup) | Out-Null
        [IO.Directory]::CreateDirectory($stage) | Out-Null
        if ($shortcutExisted) { Copy-VerifiedFile $shortcutPath (Join-Path $backup 'shortcut.lnk') }
        foreach ($name in $names) {
            $path = Join-Path $InstallPath $name
            if (Test-Path -LiteralPath $path) {
                $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
                if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    throw 'Installatiebestand is een map of link; update geweigerd.'
                }
                Copy-VerifiedFile $path (Join-Path $backup $name)
                $fileAcls[$name] = Get-Acl -LiteralPath $path -ErrorAction Stop
                $previous += $name
            }
        }
        if (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) {
            $taskXml = Export-ScheduledTask -TaskName $script:TaskName -ErrorAction Stop
            $taskXml | Set-Content -LiteralPath (Join-Path $backup 'task.xml') -Encoding UTF8 -ErrorAction Stop
            $taskSecurity = Get-UtilityTaskSecurityDescriptor
            $taskSecurity | Set-Content -LiteralPath (Join-Path $backup 'task-security.sddl') -Encoding UTF8 -ErrorAction Stop
        }
        foreach ($name in $script:PackageFiles) { Copy-VerifiedFile (Join-Path $SourcePath $name) (Join-Path $stage $name) }
        $Config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'config.json') -Encoding UTF8 -ErrorAction Stop
        $deployStarted = $true
        foreach ($name in @($script:PackageFiles) + 'config.json') {
            $path = Join-Path $InstallPath $name
            Copy-VerifiedFile (Join-Path $stage $name) $path
            Set-UtilityFilePermissions $path $Config.TargetUserSid
        }
        Set-UtilityTask $InstallPath $Config
        Set-UtilityShortcut $InstallPath $Config
        $script:UtilityVersion | Set-Content -LiteralPath (Join-Path $InstallPath 'version.txt') -Encoding ASCII -ErrorAction Stop
        Set-UtilityFilePermissions (Join-Path $InstallPath 'version.txt') $Config.TargetUserSid
        $hashes = [ordered]@{}
        foreach ($name in $script:PackageFiles) { $hashes[$name] = (Get-FileHash -LiteralPath (Join-Path $InstallPath $name) -Algorithm SHA256 -ErrorAction Stop).Hash }
        @{ Version = $script:UtilityVersion; Hashes = $hashes } | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $InstallPath 'manifest.json') -Encoding UTF8 -ErrorAction Stop
        Set-UtilityFilePermissions (Join-Path $InstallPath 'manifest.json') $Config.TargetUserSid
        Test-InstalledPackage $InstallPath
        $results = @(New-StepResult 'Installatie' 'Success')
        # Oude onderdelen pas opruimen nadat het nieuwe pakket is gecontroleerd.
        try {
            foreach ($oldTaskName in @('Opstart-Script', $LegacyTaskName) | Where-Object { $_ -and $_ -ne $script:TaskName } | Select-Object -Unique) {
                $oldTask = Get-ScheduledTask -TaskName $oldTaskName -ErrorAction SilentlyContinue
                if ($oldTask) {
                    if (($oldTask.Actions.Arguments -join ' ') -notmatch '(?i)(opstart-script|LeenlaptopSchoonmaak)\.ps1') {
                        throw 'Oude taak verwijst niet naar een herkenbaar schoonmaakscript; handmatige beoordeling vereist.'
                    }
                    Export-ScheduledTask -TaskName $oldTaskName -ErrorAction Stop |
                        Set-Content -LiteralPath (Join-Path $backup ('legacy-task_' + [guid]::NewGuid().ToString('N') + '.xml')) -Encoding UTF8 -ErrorAction Stop
                    Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false -ErrorAction Stop
                }
            }
            $legacy = Join-Path $InstallPath 'opstart-script.ps1'
            if (Test-Path -LiteralPath $legacy) { Remove-Item -LiteralPath $legacy -Force -ErrorAction Stop }
            $results += New-StepResult 'Migratie' 'Success' -Detail 'Oude LOCALAPPDATA-installatie blijft beschikbaar voor handmatig herstel.'
        } catch { $results += New-StepResult 'Migratie' 'Partial' -Failed 1 -Detail 'Nieuwe installatie werkt; oude onderdelen konden niet volledig worden verwijderd.' }
    } catch {
        $failure = $_
        if ($deployStarted) {
            foreach ($name in $names) {
                if ($previous -contains $name) {
                    Copy-VerifiedFile (Join-Path $backup $name) (Join-Path $InstallPath $name)
                    Set-Acl -LiteralPath (Join-Path $InstallPath $name) -AclObject $fileAcls[$name] -ErrorAction Stop
                }
                elseif (Test-Path -LiteralPath (Join-Path $InstallPath $name)) { Remove-Item -LiteralPath (Join-Path $InstallPath $name) -Force -ErrorAction Stop }
            }
            if ($taskXml) {
                Register-ScheduledTask -TaskName $script:TaskName -Xml $taskXml -Force -ErrorAction Stop | Out-Null
                Set-UtilityTaskPermissions -SecurityDescriptor $taskSecurity
            }
            elseif (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction Stop }
            if ($shortcutExisted) { Copy-VerifiedFile (Join-Path $backup 'shortcut.lnk') $shortcutPath }
            elseif (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force -ErrorAction Stop }
        }
        if ($originalAcl) { Set-Acl -LiteralPath $InstallPath -AclObject $originalAcl -ErrorAction Stop }
        if ($originalStateAcl) { Set-Acl -LiteralPath $state -AclObject $originalStateAcl -ErrorAction Stop }
        throw $failure
    } finally {
        try { if (Test-Path -LiteralPath $stage) {
            # Stage bevat uitsluitend onze vier releasebestanden en configuratie.
            foreach ($file in Get-ChildItem -LiteralPath $stage -File -Force) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop }
            Remove-Item -LiteralPath $stage -Force -ErrorAction Stop
        } } finally { $lock.Dispose() }
    }
    return $results
}

function Update-UtilityRetention {
    param([string]$InstallPath, [System.Collections.IDictionary]$Config)
    $cutoff = [DateTime]::Now.AddDays(-$Config.LogRetentionDays)
    $state = Join-Path $InstallPath 'state'
    foreach ($file in Get-ChildItem -LiteralPath $state -Filter 'run_*.json' -File -ErrorAction Stop) {
        if ($file.LastWriteTime -lt $cutoff) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop }
    }
    $log = Join-Path $state 'log.txt'
    if (Test-Path -LiteralPath $log) {
        if ((Get-Item -LiteralPath $log -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Logretentie geweigerd voor een link.' }
        $retained = @(Get-Content -LiteralPath $log -ErrorAction Stop | Where-Object {
            $stamp = [DateTime]::MinValue
            [DateTime]::TryParse(($_ -split ' ', 2)[0], [ref]$stamp) -and $stamp.ToUniversalTime() -ge $cutoff.ToUniversalTime()
        })
        Write-UtilityStateFile $log ($retained -join [Environment]::NewLine)
    }
    if ((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).Length -gt ($Config.MaxLogSizeMB * 1MB)) {
        Move-Item -LiteralPath $log -Destination (Join-Path $state ('log_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fffffff') + '.txt')) -ErrorAction Stop
    }
    foreach ($file in Get-ChildItem -LiteralPath $state -Filter 'log*.txt' -File -ErrorAction Stop) {
        if ($file.LastWriteTime -lt $cutoff) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop }
    }
    if ($Config.EnableBackupCleanup -and (Test-Administrator)) {
        $root = Join-Path $InstallPath 'backups'
        if (Test-Path -LiteralPath $root) {
            $backups = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)
            for ($index = 0; $index -lt $backups.Count; $index++) {
                Assert-TimeRemaining
                if ($backups[$index].LastWriteTime -lt $cutoff -or ($Config.MaxBackupCount -gt 0 -and $index -ge $Config.MaxBackupCount)) {
                    $result = Remove-UtilityFolderItems $backups[$index].FullName 'Backup'
                    if ($result.Failed) { throw 'Backupretentie kon niet volledig worden uitgevoerd.' }
                    Remove-Item -LiteralPath $backups[$index].FullName -Force -ErrorAction Stop
                }
            }
        }
    }
}

function Write-UtilityReport {
    param([string]$InstallPath, [object]$Report)
    $state = Join-Path $InstallPath 'state'
    $json = $Report | ConvertTo-Json -Depth 8
    Write-UtilityStateFile (Join-Path $state 'laatste_status.json') $json
    Write-UtilityStateFile (Join-Path $state ('run_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fffffff') + '.json')) $json
    $lines = @(
        ('Leenlaptop Schoonmaak ' + $Report.Version)
        ('Actie: ' + $Report.Action)
        ('Status: ' + $Report.Status)
    )
    foreach ($result in $Report.Results) { $lines += '{0}: {1}; verwijderd={2}; mislukt={3}; {4}' -f $result.Name, $result.Status, $result.Removed, $result.Failed, $result.Detail }
    Write-UtilityStateFile (Join-Path $state 'laatste_status.txt') ($lines -join [Environment]::NewLine)
    $log = Join-Path $state 'log.txt'
    $oldLines = @()
    if (Test-Path -LiteralPath $log) {
        if ((Get-Item -LiteralPath $log -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Logbestand is een link; rapportage gestopt.' }
        $oldLines = @(Get-Content -LiteralPath $log -ErrorAction Stop)
    }
    $oldLines += '{0:o} {1} {2} exit={3}' -f [DateTime]::UtcNow, $Report.Action, $Report.Status, $Report.ExitCode
    Write-UtilityStateFile $log ($oldLines -join [Environment]::NewLine)
}

function Write-UtilityStateFile {
    param([string]$Path, [string]$Content)
    $parent = Split-Path $Path
    Assert-SafeRoot $parent
    $temporary = Join-Path $parent ([guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $stream = [IO.File]::Open($temporary, 'CreateNew', 'Write', 'None')
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($Content + [Environment]::NewLine)
            $stream.Write($bytes, 0, $bytes.Length)
        } finally { $stream.Dispose() }
        # Verwijder een eventuele link zelf; schrijf nooit via de bestaande bestemming.
        [IO.File]::Delete($Path)
        [IO.File]::Move($temporary, $Path)
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Invoke-LeenlaptopUtility {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param([ValidateSet('Check', 'Config', 'Install', 'Cleanup')][string]$Action = 'Check',
        [string]$SourcePath = $PSScriptRoot, [Parameter(Mandatory)][string]$InstallPath,
        [string]$ConfigPath, [string]$TargetUser)
    $script:Deadline = $null
    $user = $null
    $legacyProfilePath = ''
    if ($Action -eq 'Install' -and $TargetUser) {
        $user = Resolve-TargetUser $TargetUser ''
        $legacyProfilePath = $user.ProfilePath
    }
    $loaded = Read-UtilityConfiguration $SourcePath $InstallPath $ConfigPath $legacyProfilePath
    $config = $loaded.Config
    $results = @(); $lock = $null
    $report = [pscustomobject]@{
        Version = $script:UtilityVersion; Action = $Action; Status = 'Success'; ExitCode = 0
        StartedAt = [DateTime]::UtcNow.ToString('o'); DurationSeconds = 0
        ConfigSource = $loaded.Source; Config = $config; Results = @()
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    if ($Action -in @('Check', 'Config')) {
        $report.Results = @(New-StepResult 'Configuratie' 'Success')
        if ($Action -eq 'Check') {
            if (-not $config.TargetUserSid) { $report.Results += New-StepResult 'Doelaccount' 'Partial' -Detail 'Nog niet geconfigureerd; installatie vereist -TargetUser.' }
            elseif ($config.TargetUserSid -ne (Get-CurrentUserSid)) { $report.Results += New-StepResult 'Doelaccount' 'Partial' -Detail 'Huidige account wijkt af van het doelaccount; opschoning wordt geweigerd.' }
            if (-not (Test-Path -LiteralPath (Join-Path $InstallPath 'config.json'))) { $report.Results += New-StepResult 'Installatie' 'Partial' -Detail 'Geen 1.7-configuratie gevonden.' }
            else {
                try { Test-InstalledPackage $InstallPath; $report.Results += New-StepResult 'Pakket' 'Success' }
                catch { $report.Results += New-StepResult 'Pakket' 'Failed' -Failed 1 -Detail 'Pakket ontbreekt, is gewijzigd of heeft een andere versie.' }
                if ($config.EnableStartupTask) {
                    $task = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
                    if (-not $task) { $report.Results += New-StepResult 'Geplande taak' 'Partial' -Detail 'Taak ontbreekt; installeer opnieuw.' }
                }
            }
        }
    } elseif ($Action -eq 'Install') {
        if (-not $user) { $user = Resolve-TargetUser $TargetUser $config.TargetUserSid }
        $config.TargetUserSid = $user.Sid
        Test-UtilityConfiguration $config
        if ($PSCmdlet.ShouldProcess($InstallPath, 'Pakket installeren, configuratie bewaren en voorzieningen instellen')) {
            if (-not (Test-Administrator)) { throw 'Installatie vereist administratorrechten.' }
            $legacyTaskName = ''
            if ($loaded.ContainsKey('LegacyTaskName')) { $legacyTaskName = $loaded.LegacyTaskName }
            $results = @(Install-UtilityPackage $SourcePath $InstallPath $config $legacyTaskName)
            $lock = Enter-UtilityLock $InstallPath
        } else { $results = @(New-StepResult 'Installatie' 'Planned') }
    } else {
        if (($config.TargetUserSid -and $config.TargetUserSid -ne (Get-CurrentUserSid)) -or
            (-not $config.TargetUserSid -and -not $WhatIfPreference)) {
            throw 'Opschoning geweigerd: voer uit als het geconfigureerde doelaccount. Gebruik -Check voor controle.'
        }
        $plan = @(Get-CleanupPlan $config)
        try {
            if ($plan.Count -eq 0) {
                if ($PSCmdlet.ShouldProcess('Status', 'Vastleggen dat geen opschoononderdelen zijn ingeschakeld')) {
                    if (-not (Test-Path -LiteralPath (Join-Path $InstallPath 'config.json'))) { throw 'Installeer de utility voordat u opschoont.' }
                    $lock = Enter-UtilityLock $InstallPath
                    Test-InstalledPackage $InstallPath
                    $results += New-StepResult 'Opschoning' 'Skipped' -Detail 'Geen onderdelen ingeschakeld.'
                } else { $results += New-StepResult 'Opschoning' 'Planned' }
            }
            foreach ($step in $plan) {
                if ($PSCmdlet.ShouldProcess($step.Name, 'Geconfigureerde gegevens verwijderen of systeeminstellingen resetten')) {
                    if (-not $lock) {
                        if (-not (Test-Path -LiteralPath (Join-Path $InstallPath 'config.json'))) { throw 'Installeer de utility voordat u opschoont.' }
                        $lock = Enter-UtilityLock $InstallPath
                        Test-InstalledPackage $InstallPath
                        $script:Deadline = [DateTime]::UtcNow.AddMinutes($config.MaxExecutionMinutes)
                    }
                    $results += Invoke-CleanupStep $step $config
                } else { $results += New-StepResult $step.Name 'Planned' }
            }
            if ($lock) { Assert-TimeRemaining }
        } catch { $results += New-StepResult 'Uitvoering' 'Failed' -Failed 1 -Detail 'Uitvoering afgebroken; niet uitgevoerde stappen zijn niet geslaagd.' }
    }
    try {
        if ($Action -in @('Check', 'Config')) { $results = $report.Results }
        if ($lock) {
            try { Update-UtilityRetention $InstallPath $config }
            catch { $results += New-StepResult 'Retentie' 'Partial' -Failed 1 -Detail 'Retentie kon niet volledig worden uitgevoerd.' }
        }
        $report.Results = $results
        $report.ExitCode = Get-ResultExitCode $results
        $report.Status = switch ($report.ExitCode) { 1 { 'Failed' } 2 { 'Partial' } 0 { if (@($results | Where-Object Status -eq 'Planned').Count) { 'Planned' } else { 'Success' } } }
        $report.DurationSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
        if ($lock) {
            # Rapporten bevatten geen configuratie, gebruikers-SID, paden of Wi-Fi-namen.
            $stored = $report | Select-Object Version, Action, Status, ExitCode, StartedAt, DurationSeconds, Results
            Write-UtilityReport $InstallPath $stored
        }
        return $report
    } finally {
        if ($lock) { $lock.Dispose() }
        $script:Deadline = $null
    }
}

Export-ModuleMember -Function Invoke-LeenlaptopUtility
