<#
.SYNOPSIS
    Schoonmaak- en opstartscript voor leenlaptops.

.DESCRIPTION
    Kopieert zichzelf naar een verborgen map, sluit browsers, verwijdert browserdata,
    wifi‑profielen en tijdelijke bestanden, roteert de log en registreert zichzelf als
    geplande taak bij opstart. Integreert met Windows Event Log.

.NOTES
    Auteur: Ruben Draaisma
    Datum: 2025-09-30
    VERSIE: 1.4.0
    Laatste wijziging: 2025-09-30
#>

#region Configuratie
[string]$HiddenFolderName   = 'HiddenScripts'
[string]$TaskName           = 'Opstart-Script'
[string[]]$AllowedWiFi      = @('uw-wifi')
[string[]]$BrowserList      = @('msedge','firefox','chrome')
[string]$LogFileName        = 'script.log'
[int]  $MaxLogSizeMB        = 5
[string]$EventSource        = 'OpstartScript'
[bool] $EnableShortcut      = $true      # Snelkoppeling maken ja/nee (true/false)
[bool] $EnableFirewallReset = $true      # Firewall resetten ja/nee (true/false)
[string]$ScriptVersion      = '1.4.0'    # Huidige scriptversie
[bool] $ForceUpdate         = $false     # Forceer update van bestaand script
[int]  $MaxRetries          = 3          # Maximaal aantal herhaalpogingen bij fouten
#endregion

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
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    Backup-Log
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry     = "{0} [{1}] {2}" -f $timestamp, $Level, $Message
    Add-Content -Path $LogFile -Value $entry

    $eventType = switch ($Level) {
        'ERROR' { [System.Diagnostics.EventLogEntryType]::Error }
        'WARN'  { [System.Diagnostics.EventLogEntryType]::Warning }
        default { [System.Diagnostics.EventLogEntryType]::Information }
    }
    Write-EventLog -LogName Application -Source $EventSource -EntryType $eventType -EventId 1000 -Message $entry
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
            Set-Content -Path $VersionFile -Value $ScriptVersion -Force
            Write-Log -Message "Script gekopieerd naar $dest (versie $ScriptVersion)"
        } else {
            Write-Log -Message "Script is al up-to-date in verborgen map"
        }
        
        return $dest
    } catch {
        Write-Log -Message "Fout bij kopiëren script: $($_.Exception.Message)" -Level 'ERROR'
        throw
    }
}

function Stop-Browsers {
    foreach ($name in $BrowserList) {
        try {
            Get-Process -Name $name -ErrorAction SilentlyContinue |
                Where-Object { $_.StartInfo.EnvironmentVariables['USERNAME'] -eq $env:USERNAME } |
                Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Log -Message ("Gestopt: {0}" -f $name)
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
    Write-Log -Message 'Start Wi‑Fi profiel opschoning'

    # 1) Haal alle profielen op
    $profiles = netsh wlan show profiles 2>$null |
        Where-Object { $_ -match '^\s*All User Profile\s*:' } |
        ForEach-Object { ($_ -split ':' ,2)[1].Trim() }

    if (-not $profiles) {
        Write-Log -Message 'Geen Wi‑Fi‑profielen gevonden, opschoning overgeslagen'
        return
    }

    # 2) Verwijder elk ongewenst profiel
    foreach ($wifiProfile in $profiles) {
        if ($AllowedWiFi -contains $wifiProfile) {
            Write-Log -Message ("  Behouden profiel: {0}" -f $wifiProfile)
        } else {
            Write-Log -Message ("  Verwijder profiel: {0}" -f $wifiProfile)
            netsh wlan delete profile name="$wifiProfile" | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "    Verwijdering OK"
            } else {
                Write-Log -Message ("    Fout bij verwijderen (exit code {0})" -f $LASTEXITCODE) -Level 'WARN'
            }
        }
    }

    Write-Log -Message 'Einde Wi‑Fi profiel opschoning'
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
        # Verwijder backups ouder dan 30 dagen
        $cutoffDate = (Get-Date).AddDays(-30)
        Get-ChildItem -Path $HiddenFolderPath -Filter 'backup_*' |
            Where-Object { $_.CreationTime -lt $cutoffDate } |
            ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Log -Message "Oude backup verwijderd: $($_.Name)"
            }
        
        # Verwijder oude gearchiveerde logs
        Get-ChildItem -Path $HiddenFolderPath -Filter 'script_*.log' |
            Where-Object { $_.CreationTime -lt $cutoffDate } |
            ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Log -Message "Oude log verwijderd: $($_.Name)"
            }
    } catch {
        Write-Log -Message "Fout bij opschonen oude bestanden: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Restore-FirewallDefaults {
    try {
        Write-Log -Message 'Reset Windows Firewall naar standaardinstellingen'
        netsh advfirewall reset | Out-Null
        Write-Log -Message 'Firewall reset voltooid'
    } catch {
        Write-Log -Message ("Fout bij reset firewall: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
}

function Register-StartupTask {
    param([string]$ScriptPath)

    try {
        # 1) Bestaande taak ophalen
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Log -Message "Geplande taak '$TaskName' bestaat al, geen aanpassingen nodig"
            return
        }

        # 2) Taak aanmaken
        $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME `
                        -LogonType S4U -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$true `
                        -StartWhenAvailable:$true -ExecutionTimeLimit (New-TimeSpan -Hours 72)

        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings

        Write-Log -Message "Geplande taak '$TaskName' succesvol geregistreerd"
    }
    catch {
        Write-Log -Message ("Fout bij registreren taak: {0}" -f $_.Exception.Message) -Level 'ERROR'
    }
}

function Set-ReturnShortcut {
    param(
        [string]$ShortcutName = 'Terug naar start.lnk',
        [string]$TargetScriptPath  # Vul in bij aanroep: de $destPath uit Copy-ScriptToHidden
    )

    # 1) Bepaal paden
    $desktop = [Environment]::GetFolderPath('Desktop')
    $linkPath = Join-Path $desktop $ShortcutName

    # 2) Bestaat-ie al?
    if (Test-Path $linkPath) {
        Write-Log -Message "Snelkoppeling al aanwezig: $linkPath"
        return
    }

    try {
        # 3) Maak WScript.Shell COM-object
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($linkPath)

        # 4) Instellingen voor de snelkoppeling
        $shortcut.TargetPath = 'powershell.exe'
        $shortcut.Arguments  = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TargetScriptPath`""
        $shortcut.WorkingDirectory = Split-Path $TargetScriptPath
        # Optioneel: stel een icon in, bv. PowerShell-icoon
        $shortcut.IconLocation = 'powershell.exe,0'

        # 5) Opslaan
        $shortcut.Save()

        Write-Log -Message "Snelkoppeling aangemaakt: $linkPath"
    } catch {
        Write-Log -Message ("Fout bij maken snelkoppeling: {0}" -f $_.Exception.Message) -Level 'ERROR'
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

# === Main ===
try {
    Initialize-Environment
    Write-Log -Message "Start script (versie $ScriptVersion)"
    
    $destPath = Copy-ScriptToHidden
    
    # Opschonen met retry-logica voor kritieke operaties
    Invoke-WithRetry -ScriptBlock { Stop-Browsers } -OperationName "Browser stoppen"
    Invoke-WithRetry -ScriptBlock { Clear-EdgeData } -OperationName "Edge data wissen"
    Invoke-WithRetry -ScriptBlock { Clear-FirefoxData } -OperationName "Firefox data wissen"
    Invoke-WithRetry -ScriptBlock { Clear-ChromeData } -OperationName "Chrome data wissen"
    
    Clear-WiFiProfiles  
    Clear-TempFiles     
    Clear-OldBackups    
    
    if ($EnableFirewallReset) {
        Invoke-WithRetry -ScriptBlock { Restore-FirewallDefaults } -OperationName "Firewall reset"
    }
    
    Register-StartupTask -ScriptPath $destPath
    
    if ($EnableShortcut) {
        Set-ReturnShortcut -TargetScriptPath $destPath
    }
    
    Write-Log -Message "Script voltooid zonder kritieke fouten (versie $ScriptVersion)"
} catch {
    Write-Log -Message "Beëindigd met fout: $($_.Exception.Message)" -Level 'ERROR'
    exit 1
}
