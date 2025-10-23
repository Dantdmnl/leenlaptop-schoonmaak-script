<#
.SYNOPSIS
    Schoonmaak- en opstartscript voor leenlaptops.

.DESCRIPTION
    Kopieert zichzelf naar een verborgen map, sluit browsers, verwijdert browserdata,
    wifi-profielen en tijdelijke bestanden, roteert de log en registreert zichzelf als
    geplande taak bij opstart. Integreert met Windows Event Log.
    
    AVG-COMPLIANCE:
    - Minimale logging van persoonsgegevens (geen usernames, netwerknamen)
    - Automatische logretentie van 30 dagen
    - Lokale opslag met beperkte toegang (alleen ICT)
    - Event Log zonder PII voor kritieke berichten

.NOTES
    Auteur: Ruben Draaisma
    Datum: 2025-10-23
    VERSIE: 1.5.0
    Laatste wijziging: 2025-10-23 (yyyy-mm-dd)
    AVG-conform: Minimale logging van persoonsgegevens, 30 dagen retentie
       
.EXAMPLE
    .\opstart-script.ps1
    Voert volledige opschoning uit met standaard instellingen
#>

param(
    [switch]$PrintConfig
)

#region Configuratie
[string]$HiddenFolderName   = 'HiddenScripts'
[string]$TaskName           = 'Opstart-Script'
[string[]]$AllowedWiFi      = @('uw-wifi')
[string[]]$BrowserList      = @('msedge','firefox','chrome')
[string]$LogFileName        = 'script.log'
[int]  $MaxLogSizeMB        = 5
[string]$EventSource        = 'OpstartScript'
[bool] $EnableShortcut      = $true      # Snelkoppeling maken ja/nee (true/false)
[bool] $EnableStartupTask   = $true      # Opstarttaak registreren ja/nee (true/false)
[bool] $EnableFirewallReset = $true      # Firewall resetten ja/nee (true/false)
[string]$ScriptVersion      = '1.5.0'    # Huidige scriptversie
[bool] $ForceUpdate         = $false     # Forceer update van bestaand script
[int]  $MaxRetries          = 3          # Maximaal aantal herhaalpogingen bij fouten
[int]  $MaxExecutionMinutes = 5          # Maximale uitvoeringstijd (conform ontwerp)
[int]  $LogRetentionDays    = 30         # AVG: Logretentie in dagen
#endregion

if ($PrintConfig) {
    # Geef configuratie terug in een formaat dat de batchfile direct kan inlezen (set VAR=...)
    $cfg = [ordered]@{
        HiddenFolderName    = $HiddenFolderName
        TaskName            = $TaskName
        AllowedWiFi         = ($AllowedWiFi -join ',')
        BrowserList         = ($BrowserList -join ',')
        LogFileName         = $LogFileName
        MaxLogSizeMB        = $MaxLogSizeMB
        EventSource         = $EventSource
        EnableShortcut      = $EnableShortcut
        EnableStartupTask   = $EnableStartupTask
        EnableFirewallReset = $EnableFirewallReset
        ScriptVersion       = $ScriptVersion
        ForceUpdate         = $ForceUpdate
        MaxRetries          = $MaxRetries
        MaxExecutionMinutes = $MaxExecutionMinutes
        LogRetentionDays    = $LogRetentionDays
        HiddenFolderPath    = (Join-Path $env:LOCALAPPDATA $HiddenFolderName)
    }

    foreach ($k in $cfg.Keys) {
        $v = $cfg[$k]
        Write-Output ("set PS_{0}={1}" -f $k, $v)
    }
    exit 0
}

function Initialize-Environment {
    try {
        $global:HiddenFolderPath = Join-Path $env:LOCALAPPDATA $HiddenFolderName
        if (-not (Test-Path $HiddenFolderPath)) {
            New-Item -Path $HiddenFolderPath -ItemType Directory -Force | Out-Null
        }
        # Stel verborgen attribuut in voor extra veiligheid
        $folder = Get-Item $HiddenFolderPath -Force
        $folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::Hidden
        
        $global:LogFile = Join-Path $HiddenFolderPath $LogFileName
        $global:VersionFile = Join-Path $HiddenFolderPath 'version.txt'

        # Event source registreren (vereist admin rechten)
        if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
            try {
                New-EventLog -LogName Application -Source $EventSource
            } catch {
                Write-Warning "Kan Event Log source niet registreren: $($_.Exception.Message)"
            }
        }
    } catch {
        throw "Fout bij initialiseren omgeving: $($_.Exception.Message)"
    }
}

function Backup-Log {
    if (Test-Path $LogFile) {
        $sizeMB = (Get-Item $LogFile).Length / 1MB
        if ($sizeMB -ge $MaxLogSizeMB) {
            $archive = Join-Path $HiddenFolderPath ("script_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
            Rename-Item -Path $LogFile -NewName $archive -Force
        }
    }
    
    # AVG: Verwijder logs ouder dan retentieperiode
    try {
        $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
        Get-ChildItem -Path $HiddenFolderPath -Filter 'script_*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -lt $cutoffDate } |
            ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Verbose "AVG: Oude log verwijderd na $LogRetentionDays dagen: $($_.Name)"
            }
    } catch {
        # Stille fout - mag logrotatie niet verstoren
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO',
        [switch]$SkipEventLog  # Voor berichten die geen PII mogen bevatten in Event Log
    )
    Backup-Log
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry     = "{0} [{1}] {2}" -f $timestamp, $Level, $Message
    Add-Content -Path $LogFile -Value $entry

    # AVG: Alleen niet-PII berichten naar Event Log
    if (-not $SkipEventLog) {
        $eventType = switch ($Level) {
            'ERROR' { [System.Diagnostics.EventLogEntryType]::Error }
            'WARN'  { [System.Diagnostics.EventLogEntryType]::Warning }
            default { [System.Diagnostics.EventLogEntryType]::Information }
        }
        try {
            Write-EventLog -LogName Application -Source $EventSource -EntryType $eventType -EventId 1000 -Message $entry -ErrorAction SilentlyContinue
        } catch {
            # Event Log schrijven mag niet falen
        }
    }
}

function Copy-ScriptToHidden {
    try {
        # Probeer eerst PSCommandPath, anders MyInvocation
        $source = $PSCommandPath
        if ([string]::IsNullOrEmpty($source)) {
            $source = $MyInvocation.MyCommand.Path
        }
        if ([string]::IsNullOrEmpty($source)) {
            throw "Geen geldig scriptpad gevonden."
        }

        $dest = Join-Path $HiddenFolderPath (Split-Path $source -Leaf)
        
        # Controleer of update nodig is
        $needsUpdate = $ForceUpdate -or (-not (Test-Path $dest))
        
        if (-not $needsUpdate -and (Test-Path $VersionFile)) {
            $currentVersion = Get-Content $VersionFile -ErrorAction SilentlyContinue
            if ($currentVersion -ne $ScriptVersion) {
                $needsUpdate = $true
                Write-Log -Message "Versie-update gedetecteerd: $currentVersion -> $ScriptVersion"
            }
        } else {
            $needsUpdate = $true
        }
        
        if ($needsUpdate) {
            # Maak backup van bestaand script
            if (Test-Path $dest) {
                $backupName = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Split-Path $source -Leaf)"
                $backupPath = Join-Path $HiddenFolderPath $backupName
                Copy-Item -Path $dest -Destination $backupPath -Force
                Write-Log -Message "Backup gemaakt: $backupName"
            }
            
            Copy-Item -Path $source -Destination $dest -Force
            
            # Zet ForceUpdate op $false in de gekopieerde versie om oneindige loops te voorkomen
            if ($ForceUpdate) {
                $content = Get-Content -Path $dest -Raw
                $content = $content -replace '(\$ForceUpdate\s*=\s*)\$true', '$1$false'
                Set-Content -Path $dest -Value $content -NoNewline -Force
                Write-Log -Message "ForceUpdate uitgeschakeld in gekopieerde versie"
            }
            
            Set-Content -Path $VersionFile -Value $ScriptVersion -Force
            Write-Log -Message "Script gekopieerd naar $dest (versie $ScriptVersion)"
        } else {
            Write-Log -Message "Script is al up-to-date in verborgen map"
        }
        
        return $dest
    } catch {
        Write-Log -Message "Fout bij kopieren script: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

function Stop-Browsers {
    foreach ($name in $BrowserList) {
        try {
            # AVG: Filter op proces zonder username te loggen
            $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
            if ($processes) {
                $processes | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Log -Message ("Browser gestopt: {0} ({1} processen)" -f $name, $processes.Count)
            }
        } catch {
            Write-Log -Message ("Fout bij stoppen browser {0}: {1}" -f $name, $_.Exception.Message) -Level 'WARN'
        }
    }
    Start-Sleep -Seconds 2
}

function Clear-EdgeData {
    $path = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
    if (-not (Test-Path $path)) { return }
    Get-ChildItem -Path $path -Directory |
        Where-Object Name -match '^(Default|Profile\d+)$' |
        ForEach-Object {
            $targets = 'History','Cookies','Cache','Local Storage','Network','Code Cache',
                       'GPUCache','Session Storage','Top Sites','Visited Links',
                       'Sessions','Preferences','Local State'
            foreach ($item in $targets) {
                $p = Join-Path $_.FullName $item
                if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    Write-Log -Message 'Edge data verwijderd'
}

function Clear-FirefoxData {
    $base = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (-not (Test-Path $base)) { return }
    Get-ChildItem -Path $base -Directory | ForEach-Object {
        try {
            $targets = 'places.sqlite','cookies.sqlite','cache2','storage','startupCache',
                       'sessionstore.jsonlz4','recovery.jsonlz4','previous.jsonlz4','sessionstore-backups'
            foreach ($item in $targets) {
                $p = Join-Path $_.FullName $item
                if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Get-ChildItem -Path $_.FullName -Filter 'upgrade.jsonlz4*' -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Log -Message ("Firefox data profiel '{0}' verwijderd" -f $_.Name)
        } catch {
            Write-Log -Message ("Fout bij wissen Firefox profiel '{0}': {1}" -f $_.Name, $_.Exception.Message) -Level 'WARN'
        }
    }
}

function Clear-ChromeData {
    param(
        [string]$ProfileRoot = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    )
    if (-not (Test-Path $ProfileRoot)) {
        Write-Log -Message "Chrome data-map niet gevonden: $ProfileRoot"
        return
    }

    Write-Log -Message 'Start Chrome data opruimen'
    # Voor elke profielmap (Default, Profile X, Guest Profile, enz.)
    Get-ChildItem -Path $ProfileRoot -Directory |
        Where-Object Name -match '^(Default|Profile\d+|Guest Profile)$' |
        ForEach-Object {
            $p = $_.FullName
            $targets = @(
                'History','Cookies','Cache','Local Storage','Session Storage',
                'GPUCache','Code Cache','Network Action Predictor',
                'Top Sites','Preferences','Visited Links','Sessions'
            )
            foreach ($t in $targets) {
                $itemPath = Join-Path $p $t
                if (Test-Path $itemPath) {
                    Remove-Item $itemPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Log -Message ("  Chrome-profiel verwijderd: {0}" -f $_.Name)
        }
    Write-Log -Message 'Einde Chrome data opruimen'
}

function Clear-WiFiProfiles {
    Write-Log -Message 'Start Wi-Fi profiel opschoning'

    # 1) Haal alle profielen op
    $profiles = netsh wlan show profiles 2>$null |
        Where-Object { $_ -match '^\s*All User Profile\s*:' } |
        ForEach-Object { ($_ -split ':' ,2)[1].Trim() }

    if (-not $profiles) {
        Write-Log -Message 'Geen Wi-Fi-profielen gevonden, opschoning overgeslagen'
        return
    }

    # 2) Verwijder elk ongewenst profiel (AVG: log geen netwerknamen in detail)
    $removedCount = 0
    $keptCount = 0
    foreach ($wifiProfile in $profiles) {
        if ($AllowedWiFi -contains $wifiProfile) {
            $keptCount++
            Write-Log -Message "Profiel behouden (whitelist)" -SkipEventLog
        } else {
            Write-Log -Message "Profiel verwijderd" -SkipEventLog
            netsh wlan delete profile name="$wifiProfile" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $removedCount++
            } else {
                Write-Log -Message "Fout bij verwijderen Wi-Fi profiel (exit code $LASTEXITCODE)" -Level 'WARN'
            }
        }
    }

    Write-Log -Message "Wi-Fi opschoning voltooid: $removedCount verwijderd, $keptCount behouden"
}

function Clear-TempFiles {
    try {
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log -Message 'Temp-bestanden verwijderd'
    } catch {
        Write-Log -Message "Fout bij verwijderen temp: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Clear-OldBackups {
    try {
        # AVG: Verwijder backups ouder dan retentieperiode
        $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
        Get-ChildItem -Path $HiddenFolderPath -Filter 'backup_*' -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -lt $cutoffDate } |
            ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Log -Message "AVG: Oude backup verwijderd na $LogRetentionDays dagen"
            }
    } catch {
        Write-Log -Message "Fout bij opschonen oude bestanden: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Restore-FirewallDefaults {
    try {
        Write-Log -Message 'Reset Windows Firewall naar standaardinstellingen'

        $resetOk = $false

        # Zorg dat vereiste services draaien (BFE en MpsSvc)
        foreach ($svc in 'BFE','MpsSvc') {
            try {
                $s = Get-Service -Name $svc -ErrorAction Stop
                if ($s.Status -ne 'Running') {
                    Start-Service -Name $svc -ErrorAction Stop
                    Write-Log -Message "Service gestart: $svc"
                }
            } catch {
                Write-Log -Message ("Service $svc kan niet worden gestart: {0}" -f $_.Exception.Message) -Level 'WARN'
            }
        }

        # Probeer eerst 'netsh' (bewezen betrouwbaar); controleer de exitcode
        try {
            & netsh.exe advfirewall reset *> $null
            $ec = $LASTEXITCODE
            if ($ec -eq 0) { $resetOk = $true } else { Write-Log -Message "netsh advfirewall reset mislukt (exitcode $ec)" -Level 'WARN' }
        } catch {
            Write-Log -Message ("netsh advfirewall reset faalde: {0}" -f $_.Exception.Message) -Level 'WARN'
        }

        # Valt netsh weg? Probeer de PowerShell-cmdlet (NetSecurity-module)
        if (-not $resetOk) {
            try {
                $cmd = Get-Command -Name Restore-NetFirewallDefault -ErrorAction SilentlyContinue
                if ($cmd) {
                    Restore-NetFirewallDefault -Confirm:$false -ErrorAction Stop | Out-Null
                    $resetOk = $true
                }
            } catch {
                Write-Log -Message ("Restore-NetFirewallDefault faalde: {0}" -f $_.Exception.Message) -Level 'WARN'
            }
        }

        if ($resetOk) {
            Write-Log -Message 'Firewall reset voltooid'
        } else {
            Write-Log -Message 'Firewall reset niet gelukt - mogelijk geblokkeerd door beleid of rechten' -Level 'WARN'
        }
    } catch {
        Write-Log -Message ("Fout bij reset firewall: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
    return $resetOk
}

function Set-StartupTask {
    param([string]$ScriptPath)

    try {
        # 1) Bestaande taak ophalen
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

        if ($EnableStartupTask) {
            # 2) Taak aanmaken of bijwerken
            $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                            -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
            $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
            $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME `
                            -LogonType S4U -RunLevel Highest
            # ExecutionTimeLimit afgestemd op MaxExecutionMinutes met kleine buffer (minimaal 10 minuten)
            $limitMinutes = [Math]::Max($MaxExecutionMinutes + 5, 10)
            $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$true `
                            -StartWhenAvailable:$true `
                            -ExecutionTimeLimit (New-TimeSpan -Minutes $limitMinutes)

            Register-ScheduledTask `
                -TaskName $TaskName `
                -Action $action `
                -Trigger $trigger `
                -Principal $principal `
                -Settings $settings `
                -Force | Out-Null

            if ($existing) {
                Write-Log -Message "Geplande taak '$TaskName' bijgewerkt"
                return 'updated'
            } else {
                Write-Log -Message "Geplande taak '$TaskName' succesvol geregistreerd"
                return 'created'
            }
        } else {
            # Taak moet NIET bestaan - verwijder indien aanwezig
            if ($existing) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
                Write-Log -Message "Geplande taak '$TaskName' verwijderd (uitgeschakeld in configuratie)"
                return 'removed'
            } else {
                Write-Log -Message "Geplande taak '$TaskName' niet aanwezig (zoals geconfigureerd)"
                return 'absent'
            }
        }
    }
    catch {
        Write-Log -Message "Fout bij beheren opstarttaak: $($_.Exception.Message)" -Level 'ERROR'
        return 'error'
    }
}

function Set-DesktopShortcut {
    param(
        [string]$ShortcutName = 'Terug naar start.lnk',
        [string]$TargetScriptPath  # Vul in bij aanroep: de $destPath uit Copy-ScriptToHidden
    )

    # 1) Bepaal paden
    $desktop = [Environment]::GetFolderPath('Desktop')
    $linkPath = Join-Path $desktop $ShortcutName

    try {
        if ($EnableShortcut) {
            $exists = Test-Path $linkPath

            # 2) Maak WScript.Shell COM-object
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($linkPath)

            # 3) Instellingen voor de snelkoppeling (twee paden):
            if ($EnableStartupTask) {
                # a) Met geplande taak: start de taak (elevated, geen UAC prompt)
                $shortcut.TargetPath = 'schtasks.exe'
                $shortcut.Arguments  = "/Run /TN `"$TaskName`""
                $shortcut.WorkingDirectory = $env:SystemRoot
                Write-Log -Message "Snelkoppeling start geplande taak: $TaskName"
            } else {
                # b) Zonder geplande taak: self-elevate via Start-Process -Verb RunAs (toont UAC prompt)
                $shortcut.TargetPath = 'powershell.exe'
                $shortcut.Arguments  = ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -Verb RunAs -WindowStyle Hidden -FilePath ''powershell.exe'' -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{0}""''"' -f $TargetScriptPath)
                $shortcut.WorkingDirectory = Split-Path $TargetScriptPath
                Write-Log -Message "Snelkoppeling start script met UAC elevatie: $TargetScriptPath"
            }
            # Optioneel: stel een icon in, bv. PowerShell-icoon
            $shortcut.IconLocation = 'powershell.exe,0'

            # 4) Opslaan (bijwerken of aanmaken)
            $shortcut.Save()
            if ($exists) {
                Write-Log -Message "Snelkoppeling bijgewerkt: $linkPath"
                return 'updated'
            } else {
                Write-Log -Message "Snelkoppeling aangemaakt: $linkPath"
                return 'created'
            }
        } else {
            # Snelkoppeling moet NIET bestaan - verwijder indien aanwezig
            if (Test-Path $linkPath) {
                Remove-Item -Path $linkPath -Force -ErrorAction SilentlyContinue
                Write-Log -Message "Snelkoppeling verwijderd: $linkPath (uitgeschakeld in configuratie)"
                return 'removed'
            } else {
                Write-Log -Message "Snelkoppeling niet aanwezig (zoals geconfigureerd)"
                return 'absent'
            }
        }
    } catch {
        Write-Log -Message "Fout bij beheren snelkoppeling: $($_.Exception.Message)" -Level 'ERROR'
        return 'error'
    }
}

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName,
        [int]$MaxAttempts = $MaxRetries
    )
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            & $ScriptBlock
            return
        } catch {
            Write-Log -Message "$OperationName poging $attempt/$MaxAttempts gefaald: $($_.Exception.Message)" -Level 'WARN'
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Show-CompletionStatus {
    param(
        [Parameter(Mandatory)][bool]$Success,
        [string]$ErrorMessage = '',
                [double]$ExecutionTimeSeconds,
                [string[]]$CompletedItems = @(),
                [string[]]$SkippedItems = @(),
                [string[]]$ProvisioningCompleted = @(),
                [string[]]$ProvisioningSkipped = @()
    )
    
    $statusFile = Join-Path $HiddenFolderPath 'laatste_status.txt'
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    if ($Success) {
                $lines = @()
                foreach ($item in $CompletedItems) { $lines += "+ $item" }
                foreach ($item in $SkippedItems)   { $lines += "- $item" }

                $details = ($lines -join [Environment]::NewLine)
                $provLines = @()
                foreach ($item in $ProvisioningCompleted) { $provLines += "+ $item" }
                foreach ($item in $ProvisioningSkipped)   { $provLines += "- $item" }
                $provBlock = if ($provLines.Count -gt 0) { "Voorzieningen:" + [Environment]::NewLine + ($provLines -join [Environment]::NewLine) + [Environment]::NewLine } else { '' }

                $statusMessage = @"
===================================================
OPSCHONING VOLTOOID - APPARAAT KLAAR VOOR UITLEEN
===================================================
Tijdstip: $timestamp
Versie: $ScriptVersion
Uitvoeringstijd: $([math]::Round($ExecutionTimeSeconds, 1)) seconden

$details
$provBlock

STATUS: SUCCES - Apparaat is schoon en klaar
===================================================
"@
        Write-Host $statusMessage -ForegroundColor Green
        Write-Log -Message "OPSCHONING SUCCESVOL VOLTOOID in $([math]::Round($ExecutionTimeSeconds, 1))s"
    } else {
                $lines = @()
                foreach ($item in $CompletedItems) { $lines += "+ $item" }
                foreach ($item in $SkippedItems)   { $lines += "- $item" }
                $details = if ($lines.Count -gt 0) { [Environment]::NewLine + ($lines -join [Environment]::NewLine) + [Environment]::NewLine } else { '' }
                $provLines = @()
                foreach ($item in $ProvisioningCompleted) { $provLines += "+ $item" }
                foreach ($item in $ProvisioningSkipped)   { $provLines += "- $item" }
                $provBlock = if ($provLines.Count -gt 0) { ($provLines -join [Environment]::NewLine) + [Environment]::NewLine } else { '' }

                $statusMessage = @"
===================================================
OPSCHONING MISLUKT - HANDMATIGE INTERVENTIE VEREIST
===================================================
Tijdstip: $timestamp
Versie: $ScriptVersion

X FOUT: $ErrorMessage
$details$provBlock
STATUS: FAILED - Meld dit apparaat bij ICT servicedesk
Log locatie: $LogFile
===================================================
"@
        Write-Host $statusMessage -ForegroundColor Red
        Write-Log -Message "OPSCHONING GEFAALD: $ErrorMessage" -Level 'ERROR'
    }
    
    # Schrijf status naar bestand voor servicedesk
    Set-Content -Path $statusFile -Value $statusMessage -Force
    
    # Wacht 10 seconden zodat servicedesk het kan lezen
    if (-not $Success) {
        Start-Sleep -Seconds 10
    }
}

# === Main ===
$startTime = Get-Date
$executionSuccessful = $false
$errorDetails = ''
${completedSteps} = @()
${skippedSteps} = @()
${provCompleted} = @()
${provSkipped} = @()

try {
    Initialize-Environment
    Write-Log -Message "START opschoning leenlaptop (versie $ScriptVersion)"
    
    # Timeout mechanisme (conform ontwerp: max 5 minuten)
    $timeoutJob = Start-Job -ScriptBlock {
        param($MaxMinutes)
        Start-Sleep -Seconds ($MaxMinutes * 60)
    } -ArgumentList $MaxExecutionMinutes
    
    try {
        $destPath = Copy-ScriptToHidden
        
        # Opschonen met retry-logica voor kritieke operaties - alleen browsers in de lijst
        Invoke-WithRetry -ScriptBlock { Stop-Browsers } -OperationName "Browser stoppen"
        
        # Alleen browser data wissen voor browsers in de $BrowserList
        if ($BrowserList -contains 'msedge') {
            Invoke-WithRetry -ScriptBlock { Clear-EdgeData } -OperationName "Edge data wissen"
        }
        if ($BrowserList -contains 'firefox') {
            Invoke-WithRetry -ScriptBlock { Clear-FirefoxData } -OperationName "Firefox data wissen"
        }
        if ($BrowserList -contains 'chrome') {
            Invoke-WithRetry -ScriptBlock { Clear-ChromeData } -OperationName "Chrome data wissen"
        }
        
        # Noteer resultaat voor statusoverzicht
        if ($BrowserList -and $BrowserList.Count -gt 0) {
            $completedSteps += ("Browsers gestopt en data verwijderd ({0})" -f (($BrowserList | Sort-Object) -join ', '))
        } else {
            $skippedSteps += 'Browser opschoning (geen browsers geconfigureerd)'
        }
        
        Clear-WiFiProfiles  
        Clear-TempFiles     
        Clear-OldBackups    
        # Noteer resultaten
        if ($AllowedWiFi -and $AllowedWiFi.Count -gt 0) {
            $completedSteps += 'Wi-Fi profielen gefilterd (whitelist actief)'
        } else {
            $completedSteps += 'Wi-Fi profielen opgeschoond'
        }
        $completedSteps += 'Tijdelijke bestanden opgeschoond'
        
        if ($EnableFirewallReset) {
            $fwOk = Invoke-WithRetry -ScriptBlock { Restore-FirewallDefaults } -OperationName "Firewall reset"
            if ($fwOk) {
                $completedSteps += 'Firewall gereset naar standaardinstellingen'
            } else {
                $skippedSteps  += 'Firewall reset mislukt'
            }
        } else {
            $skippedSteps += 'Firewall reset (uitgeschakeld in configuratie)'
        }
        
        # Beheer opstarttaak (aan/uit/verwijderen)
        $taskResult = Set-StartupTask -ScriptPath $destPath
        if ($EnableStartupTask) {
            switch ($taskResult) {
                'created' { $provCompleted += "Geplande taak geregistreerd: $TaskName" }
                'updated' { $provCompleted += "Geplande taak bijgewerkt: $TaskName" }
                'error'   { $provSkipped   += "Geplande taak kon niet worden ingesteld: $TaskName" }
                default   { $provSkipped   += "Geplande taak status onbekend: $TaskName" }
            }
        } else {
            switch ($taskResult) {
                'removed' { $provSkipped += "Geplande taak uitgeschakeld" }
                'absent'  { $provSkipped += "Geplande taak uitgeschakeld" }
                'error'   { $provSkipped += "Geplande taak uitschakelen mislukt" }
                default   { $provSkipped += "Geplande taak uitgeschakeld" }
            }
        }
        
        # Beheer snelkoppeling (aan/uit/verwijderen)
        $scResult = Set-DesktopShortcut -TargetScriptPath $destPath
        if ($EnableShortcut) {
            switch ($scResult) {
                'created' { $provCompleted += "Snelkoppeling op bureaublad aangemaakt" }
                'updated' { $provCompleted += "Snelkoppeling op bureaublad bijgewerkt" }
                'error'   { $provSkipped   += "Snelkoppeling aanmaken/bijwerken mislukt" }
                default   { $provSkipped   += "Snelkoppeling status onbekend" }
            }
        } else {
            switch ($scResult) {
                'removed' { $provSkipped += "Snelkoppeling uitgeschakeld" }
                'absent'  { $provSkipped += "Snelkoppeling uitgeschakeld" }
                'error'   { $provSkipped += "Snelkoppeling verwijderen mislukt" }
                default   { $provSkipped += "Snelkoppeling uitgeschakeld" }
            }
        }
        
        # Check of we binnen de tijd zijn gebleven
        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalMinutes -gt $MaxExecutionMinutes) {
            throw "Maximale uitvoeringstijd ($MaxExecutionMinutes minuten) overschreden"
        }
        
        $executionSuccessful = $true
        Write-Log -Message "EINDE opschoning - alle taken succesvol voltooid"
        
    } finally {
        # Stop timeout job
        if ($timeoutJob) {
            Stop-Job -Job $timeoutJob -ErrorAction SilentlyContinue
            Remove-Job -Job $timeoutJob -Force -ErrorAction SilentlyContinue
        }
    }
    
} catch {
    $executionSuccessful = $false
    $errorDetails = $_.Exception.Message
    Write-Log -Message "KRITIEKE FOUT tijdens opschoning: $errorDetails" -Level 'ERROR'
} finally {
    # Bereken totale uitvoeringstijd
    $totalSeconds = ((Get-Date) - $startTime).TotalSeconds
    
    # Toon duidelijke status voor servicedesk (conform ontwerp: SUCCES/FAIL)
    Show-CompletionStatus -Success $executionSuccessful -ErrorMessage $errorDetails -ExecutionTimeSeconds $totalSeconds -CompletedItems $completedSteps -SkippedItems $skippedSteps -ProvisioningCompleted $provCompleted -ProvisioningSkipped $provSkipped
    
    # Exit code voor monitoring
    if (-not $executionSuccessful) {
        exit 1
    }
}
