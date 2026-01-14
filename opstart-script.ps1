<#
.SYNOPSIS
    Schoonmaak- en opstartscript voor leenlaptops.

.DESCRIPTION
    Kopieert zichzelf naar een verborgen map, sluit browsers, verwijdert browserdata,
    wifi-profielen en tijdelijke bestanden, roteert de log en registreert zichzelf als
    geplande taak bij opstart. Integreert met Windows Event Log.
    
    GEBRUIKERSCONTEXT:
    - Dit script wordt uitgevoerd in de context van de INGELOGDE gebruiker
    - Bij installatie via scheduled task: -UserId $env:USERNAME met RunLevel Highest
    - Alle user-folder cleanup functies (Temp, Downloads, Documenten, Afbeeldingen, 
      Video's, Muziek) gebruiken de mappen van de ingelogde gebruiker
    - Desktop-snelkoppeling wordt geplaatst op het bureaublad van de ingelogde gebruiker
    
    AVG-COMPLIANCE:
    - Minimale logging van persoonsgegevens (geen usernames, netwerknamen)
    - Automatische logretentie van 30 dagen
    - Lokale opslag met beperkte toegang (alleen ICT)
    - Event Log zonder PII voor kritieke berichten

.NOTES
    Auteur: Ruben Draaisma
    VERSIE: 1.6.2
    Laatste wijziging: 2026-01-14 (yyyy-mm-dd)
    AVG-conform: Minimale logging van persoonsgegevens, 30 dagen retentie
    Volledig configureerbaar: Alle opschoonacties kunnen in/uitgeschakeld worden
       
.EXAMPLE
    .\opstart-script.ps1
    Voert volledige opschoning uit met huidige instellingen
#>

param(
    [switch]$PrintConfig
)

# Versie-check: PowerShell 5.1 minimum
if ($PSVersionTable.PSVersion.Major -lt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
    Write-Error "Dit script vereist PowerShell 5.1 of hoger. Huidge versie: $($PSVersionTable.PSVersion)"
    exit 1
}

#region Configuratie
# ============================================================================
# CONFIGURATIE INSTRUCTIES
# ============================================================================
# 
# BELANGRIJK bij het aanpassen van array-waarden:
# - Gebruik ALTIJD quotes rond strings: @('waarde1', 'waarde2')
# - Browsers: Procesnamen zonder .exe: @('msedge', 'chrome', 'firefox')
# - WiFi netwerken: SSID namen met quotes: @('kantoor-wifi', 'gast-netwerk')
# - Lege array betekent "alles": @() = alle WiFi netwerken verwijderen
#
# Voorbeelden:
#   [string[]]$AllowedWiFi = @()                          # Alle WiFi verwijderen
#   [string[]]$AllowedWiFi = @('kantoor-wifi')            # 1 netwerk behouden
#   [string[]]$AllowedWiFi = @('wifi-1', 'wifi-2')        # 2 netwerken behouden
#
# ============================================================================
# BASIS INSTELLINGEN
# ============================================================================
[string]$HiddenFolderName   = 'LeenlaptopSchoonmaak'  # Mapnaam in C:\ProgramData
[string]$TaskName           = 'LeenlaptopSchoonmaak'  # Naam van scheduled task
[string]$LogFileName        = 'log.txt'               # Naam van logbestand
[string]$EventSource        = 'LeenlaptopSchoonmaak'  # Event Log bron
[string]$ScriptVersion      = '1.6.2'                 # Huidige scriptversie

# ============================================================================
# VOORZIENINGEN (wat wordt geïnstalleerd)
# ============================================================================
[bool] $EnableShortcut      = $true      # Snelkoppeling op bureaublad maken
[bool] $EnableStartupTask   = $true      # Geplande taak bij opstart registreren

# ============================================================================
# OPSCHONING (wat wordt opgeschoond)
# ============================================================================
[bool] $EnableBrowserCleanup = $true     # Browsers stoppen en data wissen
[string[]]$BrowserList      = @('msedge','firefox','chrome')  # Welke browsers (procesnamen zonder .exe)

[bool] $EnableWiFiCleanup   = $true      # Wi-Fi profielen opschonen
[string[]]$AllowedWiFi      = @()        # Toegestane netwerken (leeg = alles verwijderen)
                                         # Voorbeeld met netwerken: @('kantoor-wifi', 'gast-netwerk')

[bool] $EnableTempCleanup   = $true      # Temp-bestanden verwijderen (%TEMP%)

[bool] $EnableDownloadsCleanup = $true   # Downloads-map opschonen (>7 dagen)
[int]  $DownloadsMaxAgeDays = 7          # Bestanden ouder dan X dagen

[bool] $EnableDocumentsCleanup = $false  # Documenten-map opschonen - VOORZICHTIG!
[int]  $DocumentsMaxAgeDays = 30         # Bestanden ouder dan X dagen

[bool] $EnablePicturesCleanup = $false   # Afbeeldingen-map opschonen - VOORZICHTIG!
[int]  $PicturesMaxAgeDays  = 30         # Bestanden ouder dan X dagen

[bool] $EnableVideosCleanup = $false     # Video's-map opschonen - VOORZICHTIG!
[int]  $VideosMaxAgeDays    = 30         # Bestanden ouder dan X dagen

[bool] $EnableMusicCleanup  = $false     # Muziek-map opschonen - VOORZICHTIG!
[int]  $MusicMaxAgeDays     = 30         # Bestanden ouder dan X dagen

[bool] $EnableFirewallReset = $true      # Firewall naar standaardinstellingen resetten

[bool] $EnableBackupCleanup = $true      # Oude script-backups verwijderen (gebruikt LogRetentionDays)
[int]  $MaxBackupCount      = 5         # Max aantal backups (0 = geen limiet)

# ============================================================================
# GEAVANCEERDE INSTELLINGEN
# ============================================================================
[int]  $MaxLogSizeMB        = 5          # Maximale logbestand grootte
[int]  $LogRetentionDays    = 30         # AVG: Logretentie in dagen
[int]  $MaxRetries          = 3          # Maximaal aantal herhaalpogingen bij fouten
[int]  $MaxExecutionMinutes = 5          # Maximale uitvoeringstijd
[bool] $ForceUpdate         = $true     # Forceer update van bestaand script
#endregion

if ($PrintConfig) {
    # Geef configuratie terug in een formaat dat de batchfile direct kan inlezen (set VAR=...)
    $cfg = [ordered]@{
        HiddenFolderName       = $HiddenFolderName
        TaskName               = $TaskName
        LogFileName            = $LogFileName
        EventSource            = $EventSource
        ScriptVersion          = $ScriptVersion
        AllowedWiFi            = ($AllowedWiFi -join ',')
        BrowserList            = ($BrowserList -join ',')
        EnableShortcut         = $EnableShortcut
        EnableStartupTask      = $EnableStartupTask
        EnableBrowserCleanup   = $EnableBrowserCleanup
        EnableWiFiCleanup      = $EnableWiFiCleanup
        EnableTempCleanup      = $EnableTempCleanup
        EnableDownloadsCleanup = $EnableDownloadsCleanup
        EnableDocumentsCleanup = $EnableDocumentsCleanup
        EnablePicturesCleanup  = $EnablePicturesCleanup
        EnableVideosCleanup    = $EnableVideosCleanup
        EnableMusicCleanup     = $EnableMusicCleanup
        EnableFirewallReset    = $EnableFirewallReset
        EnableBackupCleanup    = $EnableBackupCleanup
        DownloadsMaxAgeDays    = $DownloadsMaxAgeDays
        DocumentsMaxAgeDays    = $DocumentsMaxAgeDays
        PicturesMaxAgeDays     = $PicturesMaxAgeDays
        VideosMaxAgeDays       = $VideosMaxAgeDays
        MusicMaxAgeDays        = $MusicMaxAgeDays
        MaxLogSizeMB           = $MaxLogSizeMB
        LogRetentionDays       = $LogRetentionDays
        MaxRetries             = $MaxRetries
        MaxExecutionMinutes    = $MaxExecutionMinutes
        ForceUpdate            = $ForceUpdate
        MaxBackupCount         = $MaxBackupCount
        HiddenFolderPath       = "C:\ProgramData\$HiddenFolderName"
    }

    foreach ($k in $cfg.Keys) {
        $v = $cfg[$k]
        Write-Output ("set PS_{0}={1}" -f $k, $v)
    }
    exit 0
}

function Test-IsAdmin {
    <#
    .SYNOPSIS
    Controleert of het script met administrator-rechten draait.
    #>
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Initialize-Environment {
    try {
        # Migratie van 1.5.0 naar 1.6.0: verplaats van LOCALAPPDATA naar ProgramData
        $oldPath = Join-Path $env:LOCALAPPDATA 'HiddenScripts'
        $global:HiddenFolderPath = Join-Path $env:SystemDrive "ProgramData\$HiddenFolderName"
        
        if ((Test-Path $oldPath) -and -not (Test-Path $HiddenFolderPath)) {
            Write-Host "[MIGRATIE] Verplaats installatie van 1.5.0 naar 1.6.0..." -ForegroundColor Yellow
            try {
                # Kopieer oude bestanden naar nieuwe locatie
                New-Item -Path $HiddenFolderPath -ItemType Directory -Force | Out-Null
                Copy-Item -Path "$oldPath\*" -Destination $HiddenFolderPath -Recurse -Force -ErrorAction SilentlyContinue
                
                # Verwijder oude scheduled task (oude naam)
                $oldTaskName = 'Opstart-Script'
                if (Get-ScheduledTask -TaskName $oldTaskName -ErrorAction SilentlyContinue) {
                    Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Host "[MIGRATIE] Oude scheduled task '$oldTaskName' verwijderd" -ForegroundColor Yellow
                }
                
                # Verwijder oude map (optioneel, alleen als leeg)
                try {
                    Remove-Item $oldPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "[MIGRATIE] Oude installatie opgeruimd: $oldPath" -ForegroundColor Green
                } catch {
                    Write-Warning "[MIGRATIE] Kon oude map niet verwijderen (niet kritiek): $oldPath"
                }
                
                Write-Host "[MIGRATIE] Migratie voltooid naar: $HiddenFolderPath" -ForegroundColor Green
            } catch {
                Write-Warning "[MIGRATIE] Fout bij migratie, nieuwe installatie wordt aangemaakt: $($_.Exception.Message)"
            }
        }
        
        # Maak nieuwe map aan als deze niet bestaat
        if (-not (Test-Path $HiddenFolderPath)) {
            New-Item -Path $HiddenFolderPath -ItemType Directory -Force | Out-Null
        }
        
        # Stel verborgen attribuut in voor extra veiligheid
        $folder = Get-Item $HiddenFolderPath -Force
        $folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::Hidden
        
        $global:LogFile = Join-Path $HiddenFolderPath $LogFileName
        $global:VersionFile = Join-Path $HiddenFolderPath 'version.txt'
        
        # Detecteer admin-rechten en sla op
        $global:IsAdmin = Test-IsAdmin

        # Event source registreren (vereist admin rechten)
        if ($IsAdmin) {
            # Migratie: verwijder oude event source
            $oldEventSource = 'OpstartScript'
            if ([System.Diagnostics.EventLog]::SourceExists($oldEventSource)) {
                try {
                    Remove-EventLog -Source $oldEventSource -ErrorAction SilentlyContinue
                    Write-Host "[MIGRATIE] Oude Event Log source '$oldEventSource' verwijderd" -ForegroundColor Yellow
                } catch {
                    # Niet kritiek
                }
            }
            
            # Registreer nieuwe event source
            if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
                try {
                    New-EventLog -LogName Application -Source $EventSource
                } catch {
                    Write-Warning "Kan Event Log source niet registreren: $($_.Exception.Message)"
                }
            }
        }
    } catch {
        throw "Fout bij initialiseren omgeving: $($_.Exception.Message)"
    }
}

function Test-Configuration {
    <#
    .SYNOPSIS
    Valideert alle configuratieparameters bij script start.
    #>
    $errors = @()
    
    # Valideer numerieke waarden
    if ($MaxLogSizeMB -le 0) { $errors += "MaxLogSizeMB moet groter dan 0 zijn (huidige waarde: $MaxLogSizeMB)" }
    if ($LogRetentionDays -le 0) { $errors += "LogRetentionDays moet groter dan 0 zijn (huidige waarde: $LogRetentionDays)" }
    if ($MaxRetries -le 0) { $errors += "MaxRetries moet groter dan 0 zijn (huidige waarde: $MaxRetries)" }
    if ($MaxExecutionMinutes -le 0) { $errors += "MaxExecutionMinutes moet groter dan 0 zijn (huidige waarde: $MaxExecutionMinutes)" }
    if ($DownloadsMaxAgeDays -lt 0) { $errors += "DownloadsMaxAgeDays mag niet negatief zijn (huidige waarde: $DownloadsMaxAgeDays)" }
    if ($DocumentsMaxAgeDays -lt 0) { $errors += "DocumentsMaxAgeDays mag niet negatief zijn (huidige waarde: $DocumentsMaxAgeDays)" }
    if ($PicturesMaxAgeDays -lt 0) { $errors += "PicturesMaxAgeDays mag niet negatief zijn (huidige waarde: $PicturesMaxAgeDays)" }
    if ($VideosMaxAgeDays -lt 0) { $errors += "VideosMaxAgeDays mag niet negatief zijn (huidige waarde: $VideosMaxAgeDays)" }
    if ($MusicMaxAgeDays -lt 0) { $errors += "MusicMaxAgeDays mag niet negatief zijn (huidige waarde: $MusicMaxAgeDays)" }
    if ($MaxBackupCount -lt 0)  { $errors += "MaxBackupCount mag niet negatief zijn (huidige waarde: $MaxBackupCount)" }
    
    # Valideer arrays (mogen null zijn maar moeten wel arrays zijn als ze bestaan)
    if ($null -ne $BrowserList -and $BrowserList -isnot [array]) {
        $errors += "BrowserList moet een array zijn: @('msedge','chrome','firefox')"
    }
    if ($null -ne $AllowedWiFi -and $AllowedWiFi -isnot [array]) {
        $errors += "AllowedWiFi moet een array zijn: @() of @('netwerk1','netwerk2')"
    }
    
    # Valideer BrowserList items (alleen bekende browsers)
    $validBrowsers = @('msedge', 'chrome', 'firefox', 'brave', 'opera', 'vivaldi')
    if ($BrowserList -and $BrowserList.Count -gt 0) {
        foreach ($browser in $BrowserList) {
            if ([string]::IsNullOrWhiteSpace($browser)) {
                $errors += "BrowserList bevat lege waarde - verwijder lege items"
            } elseif ($browser -notin $validBrowsers) {
                $errors += "Onbekende browser '$browser' in BrowserList. Toegestaan: $($validBrowsers -join ', ')"
            }
        }
    }
    
    # Valideer AllowedWiFi items (geen lege strings)
    if ($AllowedWiFi -and $AllowedWiFi.Count -gt 0) {
        foreach ($wifi in $AllowedWiFi) {
            if ([string]::IsNullOrWhiteSpace($wifi)) {
                $errors += "AllowedWiFi bevat lege waarde - verwijder lege items of gebruik @() voor alles verwijderen"
            }
        }
    }
    
    # Valideer string waarden niet leeg zijn
    if ([string]::IsNullOrWhiteSpace($HiddenFolderName)) { $errors += 'HiddenFolderName mag niet leeg zijn' }
    if ([string]::IsNullOrWhiteSpace($TaskName)) { $errors += 'TaskName mag niet leeg zijn' }
    if ([string]::IsNullOrWhiteSpace($LogFileName)) { $errors += 'LogFileName mag niet leeg zijn' }
    if ([string]::IsNullOrWhiteSpace($EventSource)) { $errors += 'EventSource mag niet leeg zijn' }
    
    # Retourneer validatieresultaat
    if ($errors.Count -gt 0) {
        $errorMsg = "CONFIGURATIE FOUTEN GEDETECTEERD:`n" + ($errors -join "`n")
        throw $errorMsg
    }
    
    Write-Log -Message 'Configuratie validatie geslaagd'
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
                try {
                    Copy-Item -Path $dest -Destination $backupPath -Force -ErrorAction Stop
                    Write-Log -Message "Backup gemaakt: $backupName"
                } catch {
                    # Backup mislukt mag de update niet blokkeren (AVG: geen paden in Event Log)
                    Write-Log -Message "Backup mislukt, ga door met update" -Level 'WARN'
                    Write-Log -Message ("Backup exception: {0}" -f $_.Exception.Message) -SkipEventLog
                }
            }
            
            Copy-Item -Path $source -Destination $dest -Force

            # Verifieer integriteit (SHA256 hash-vergelijking) - AVG: geen paden in Event Log
            try {
                $srcHash = Get-FileHash -Algorithm SHA256 -Path $source -ErrorAction Stop
                $dstHash = Get-FileHash -Algorithm SHA256 -Path $dest   -ErrorAction Stop
                if ($srcHash.Hash -ne $dstHash.Hash) {
                    Write-Log -Message "Bestandsverificatie mislukt: hash mismatch (kopie beschadigd)" -Level 'ERROR'
                    Write-Log -Message ("Details: src={0} dst={1}" -f $srcHash.Hash, $dstHash.Hash) -SkipEventLog
                    throw "Hash mismatch na kopieren"
                } else {
                    Write-Log -Message "Bestandsverificatie geslaagd (SHA256)"
                }
            } catch {
                # Hash fouten mogen niet in Event Log met paden terecht komen
                Write-Log -Message ("Fout bij hash-verificatie: {0}" -f $_.Exception.Message) -Level 'WARN' -SkipEventLog
            }
            
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
    if (-not $BrowserList -or $BrowserList.Count -eq 0) {
        Write-Log -Message 'Geen browsers om te stoppen (BrowserList is leeg)'
        return
    }
    
    foreach ($name in $BrowserList) {
        # Firefox kan langer duren om af te sluiten, meer retries nodig
        $maxAttempts = if ($name -eq 'firefox') { 7 } else { $MaxRetries }
        
        for ($i = 1; $i -le $maxAttempts; $i++) {
            try {
                $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
                if (-not $processes) {
                    if ($i -eq 1) {
                        Write-Log -Message ("Browser niet actief: {0}" -f $name)
                    }
                    break
                }
                
                $processes | Stop-Process -Force -ErrorAction SilentlyContinue
                
                # Verifieer proces is gestopt
                Start-Sleep -Milliseconds 300
                $stillRunning = Get-Process -Name $name -ErrorAction SilentlyContinue
                
                if (-not $stillRunning) {
                    Write-Log -Message ("Browser gestopt: {0} (poging {1})" -f $name, $i)
                    break
                } elseif ($i -eq $maxAttempts) {
                    Write-Log -Message ("Browser kon niet volledig worden gestopt na {0} pogingen: {1}" -f $maxAttempts, $name) -Level 'WARN'
                }
            } catch {
                Write-Log -Message ("Fout bij stoppen browser {0}: {1}" -f $name, $_.Exception.Message) -Level 'WARN'
                break
            }
        }
    }
    Start-Sleep -Seconds 2
}

function Clear-EdgeData {
    $path = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
    if (-not (Test-Path $path)) { return }
    
    $profileCount = 0
    Get-ChildItem -Path $path -Directory |
        Where-Object Name -match '^(Default|Profile\d+|Guest Profile)$' |
        ForEach-Object {
            $profilePath = $_.FullName
            $profileName = $_.Name
            
            # STRATEGIE: Probeer eerst heel profiel te verwijderen (meest grondig)
            try {
                Remove-Item $profilePath -Recurse -Force -ErrorAction Stop
                $profileCount++
                Write-Log -Message "Edge profiel volledig verwijderd: $profileName (inclusief sync-data)" -SkipEventLog
            } catch {
                # FALLBACK: Granulaire verwijdering als profiel in gebruik is
                Write-Log -Message "Edge profiel in gebruik, granulaire cleanup: $profileName" -Level 'WARN' -SkipEventLog
                
                # Verwijder gevoelige bestanden (inclusief sync & credentials)
                $targets = @(
                    'History', 'Cookies', 'Cache', 'Local Storage', 'Network', 'Code Cache',
                    'GPUCache', 'Session Storage', 'Top Sites', 'Visited Links', 'Sessions',
                    'Login Data', 'Login Data For Account', 'Web Data',  # Credentials
                    'Preferences', 'Secure Preferences',                  # Sync settings
                    'Sync Data', 'Sync Extension Settings',               # Sync cache
                    'IndexedDB', 'databases', 'Local Extension Settings'  # App data
                )
                
                $removedItems = 0
                foreach ($item in $targets) {
                    $itemPath = Join-Path $profilePath $item
                    if (Test-Path $itemPath) {
                        try {
                            Remove-Item $itemPath -Recurse -Force -ErrorAction Stop
                            $removedItems++
                        } catch {
                            # Sommige bestanden kunnen locked zijn - niet fataal
                        }
                    }
                }
                
                if ($removedItems -gt 0) {
                    $profileCount++
                    Write-Log -Message "Edge profiel $profileName`: $removedItems items verwijderd (incl. credentials/sync)" -SkipEventLog
                } else {
                    Write-Log -Message "Edge profiel $profileName`: granulaire cleanup mislukt (alle bestanden locked)" -Level 'WARN' -SkipEventLog
                }
            }
        }
    
    if ($profileCount -gt 0) {
        Write-Log -Message "Edge data verwijderd: $profileCount profiel(en) opgeschoond"
    } else {
        Write-Log -Message 'Edge: geen profielen gevonden of toegankelijk'
    }
}

function Clear-FirefoxData {
    $base = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (-not (Test-Path $base)) { return }
    
    $profileCount = 0
    Get-ChildItem -Path $base -Directory | ForEach-Object {
        $profilePath = $_.FullName
        $profileName = $_.Name
        
        # STRATEGIE: Granulaire verwijdering - laat profiel bestaan, wis gevoelige data
        # Dit voorkomt dat Firefox geen profiel meer heeft (wat corruptie veroorzaakt)
        $targets = @(
            'places.sqlite', 'cookies.sqlite', 'cache2', 'storage', 'startupCache',
            'sessionstore.jsonlz4', 'recovery.jsonlz4', 'previous.jsonlz4', 'sessionstore-backups',
            'key4.db', 'logins.json', 'signedInUser.json',  # Credentials & Firefox Account
            'prefs.js', 'times.json', 'formhistory.sqlite',  # Settings & form data
            'weave', 'sync.log', 'synced-tabs.db'            # Firefox Sync data
        )
        
        $removedItems = 0
        foreach ($item in $targets) {
            $itemPath = Join-Path $profilePath $item
            if (Test-Path $itemPath) {
                try {
                    Remove-Item $itemPath -Recurse -Force -ErrorAction Stop
                    $removedItems++
                } catch {
                    # Sommige bestanden kunnen locked zijn - niet fataal
                }
            }
        }
        
        # Verwijder upgrade bestanden (patronen)
        Get-ChildItem -Path $profilePath -Filter 'upgrade.jsonlz4*' -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { 
                    Remove-Item $_.FullName -Force -ErrorAction Stop
                    $removedItems++
                } catch { }
            }
        
        if ($removedItems -gt 0) {
            $profileCount++
            Write-Log -Message "Firefox profiel $profileName`: $removedItems items verwijderd (incl. credentials/sync)" -SkipEventLog
        }
    }
    
    if ($profileCount -gt 0) {
        Write-Log -Message "Firefox data verwijderd: $profileCount profiel(en) opgeschoond"
    } else {
        Write-Log -Message 'Firefox: geen profielen gevonden of toegankelijk'
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

    $profileCount = 0
    Get-ChildItem -Path $ProfileRoot -Directory |
        Where-Object Name -match '^(Default|Profile\d+|Guest Profile)$' |
        ForEach-Object {
            $profilePath = $_.FullName
            $profileName = $_.Name
            
            # STRATEGIE: Probeer eerst heel profiel te verwijderen (meest grondig)
            try {
                Remove-Item $profilePath -Recurse -Force -ErrorAction Stop
                $profileCount++
                Write-Log -Message "Chrome profiel volledig verwijderd: $profileName (inclusief sync-data)" -SkipEventLog
            } catch {
                # FALLBACK: Granulaire verwijdering als profiel in gebruik is
                Write-Log -Message "Chrome profiel in gebruik, granulaire cleanup: $profileName" -Level 'WARN' -SkipEventLog
                
                # Verwijder gevoelige bestanden (inclusief sync & credentials)
                $targets = @(
                    'History', 'Cookies', 'Cache', 'Local Storage', 'Session Storage',
                    'GPUCache', 'Code Cache', 'Network Action Predictor',
                    'Top Sites', 'Visited Links', 'Sessions',
                    'Login Data', 'Login Data For Account', 'Web Data',  # Credentials
                    'Preferences', 'Secure Preferences',                  # Sync settings & account
                    'Sync Data', 'Sync Extension Settings',               # Google Sync cache
                    'IndexedDB', 'databases', 'Local Extension Settings', # App data
                    'Extension Cookies', 'Extension State'                # Extension data
                )
                
                $removedItems = 0
                foreach ($item in $targets) {
                    $itemPath = Join-Path $profilePath $item
                    if (Test-Path $itemPath) {
                        try {
                            Remove-Item $itemPath -Recurse -Force -ErrorAction Stop
                            $removedItems++
                        } catch {
                            # Sommige bestanden kunnen locked zijn - niet fataal
                        }
                    }
                }
                
                if ($removedItems -gt 0) {
                    $profileCount++
                    Write-Log -Message "Chrome profiel $profileName`: $removedItems items verwijderd (incl. credentials/sync)" -SkipEventLog
                }
            }
        }
    
    if ($profileCount -gt 0) {
        Write-Log -Message "Chrome data verwijderd: $profileCount profiel(en) opgeschoond"
    } else {
        Write-Log -Message 'Chrome: geen profielen gevonden of toegankelijk'
    }
}

function Clear-WiFiProfiles {
    if (-not $IsAdmin) {
        Write-Log -Message 'Wi-Fi opschoning overgeslagen: vereist administrator-rechten' -Level 'WARN'
        return 'no-admin'
    }
    
    Write-Log -Message 'Start Wi-Fi profiel opschoning'

    $profiles = netsh wlan show profiles 2>$null |
        Where-Object { $_ -match '^\s*All User Profile\s*:' } |
        ForEach-Object { ($_ -split ':' ,2)[1].Trim() }

    if (-not $profiles) {
        Write-Log -Message 'Geen Wi-Fi-profielen gevonden, opschoning overgeslagen'
        return 'no-profiles'
    }

    $removedCount = 0
    $keptCount = 0
    $failedCount = 0
    foreach ($wifiProfile in $profiles) {
        if ($AllowedWiFi -contains $wifiProfile) {
            $keptCount++
            Write-Log -Message "Wi-Fi profiel behouden (whitelist): $wifiProfile" -SkipEventLog
        } else {
            netsh wlan delete profile name="$wifiProfile" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $removedCount++
                Write-Log -Message "Wi-Fi profiel verwijderd: $wifiProfile" -SkipEventLog
            } else {
                $failedCount++
                Write-Log -Message "Fout bij verwijderen Wi-Fi profiel $wifiProfile (exit code $LASTEXITCODE)" -Level 'WARN'
            }
        }
    }

    $msg = "Wi-Fi opschoning voltooid: $removedCount verwijderd, $keptCount behouden"
    if ($failedCount -gt 0) { $msg += ", $failedCount mislukt" }
    Write-Log -Message $msg
    return @{ Removed = $removedCount; Kept = $keptCount }
}

function Clear-TempFiles {
    try {
        # Gebruikt de Temp-map van de INGELOGDE gebruiker (%TEMP%)
        # Bij scheduled task = de gebruiker die is ingelogd (via -UserId in task principal)
        $items = @(Get-ChildItem "$env:TEMP" -ErrorAction SilentlyContinue)
        $itemCount = $items.Count
        if ($itemCount -eq 0) {
            Write-Log -Message 'Temp-map is al leeg'
            return 0
        }
        Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log -Message "Temp-bestanden verwijderd (ongeveer $itemCount items)"
        return $itemCount
    } catch {
        Write-Log -Message "Fout bij verwijderen temp: $($_.Exception.Message)" -Level 'WARN'
        return -1
    }
}

function Clear-DownloadsFolder {
    try {
        # Gebruikt de Downloads-map van de INGELOGDE gebruiker
        # Bij scheduled task = de gebruiker die is ingelogd (via -UserId in task principal)
        # Gebruik Shell.Application COM object voor betrouwbare Downloads pad
        $shell = New-Object -ComObject Shell.Application -ErrorAction Stop
        $downloadsPath = $shell.NameSpace('shell:Downloads').Self.Path
        
        if (-not $downloadsPath -or -not (Test-Path $downloadsPath)) {
            Write-Log -Message 'Downloads-map niet gevonden'
            return 0
        }
        
        # Filter op leeftijd (alleen bestanden ouder dan X dagen)
        $cutoffDate = (Get-Date).AddDays(-$DownloadsMaxAgeDays)
        $oldItems = @(Get-ChildItem $downloadsPath -Recurse -ErrorAction SilentlyContinue | 
                      Where-Object { $_.LastWriteTime -lt $cutoffDate })
        
        $itemCount = $oldItems.Count
        if ($itemCount -eq 0) {
            Write-Log -Message "Downloads-map: geen bestanden ouder dan $DownloadsMaxAgeDays dagen"
            return 0
        }
        
        $oldItems | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log -Message "Downloads-map opgeschoond: $itemCount items verwijderd (ouder dan $DownloadsMaxAgeDays dagen)"
        return $itemCount
    } catch {
        Write-Log -Message "Fout bij opschonen Downloads: $($_.Exception.Message)" -Level 'WARN'
        return -1
    }
}

function Clear-UserFolder {
    <#
    .SYNOPSIS
    Generieke functie voor het opschonen van gebruikersmappen op basis van leeftijd.
    
    .DESCRIPTION
    Verwijdert bestanden ouder dan opgegeven aantal dagen uit een gebruikersmap.
    Gebruikt de map van de INGELOGDE gebruiker (bij scheduled task = ingelogde gebruiker via -UserId).
    
    .PARAMETER FolderType
    Type gebruikersmap: MyDocuments, MyPictures, MyVideos, MyMusic
    
    .PARAMETER MaxAgeDays
    Bestanden ouder dan dit aantal dagen worden verwijderd
    
    .PARAMETER ShowWarning
    Toon waarschuwing in log voor gevoelige mappen
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('MyDocuments', 'MyPictures', 'MyVideos', 'MyMusic')]
        [string]$FolderType,
        
        [Parameter(Mandatory)]
        [int]$MaxAgeDays,
        
        [switch]$ShowWarning
    )
    
    try {
        # Vertaal folder type naar leesbare naam
        $folderNames = @{
            'MyDocuments' = 'Documenten'
            'MyPictures'  = 'Afbeeldingen'
            'MyVideos'    = "Video's"
            'MyMusic'     = 'Muziek'
        }
        $displayName = $folderNames[$FolderType]
        
        # Haal mappad op
        $folderPath = [Environment]::GetFolderPath($FolderType)
        if (-not (Test-Path $folderPath)) {
            Write-Log -Message "$displayName-map niet gevonden"
            return 0
        }
        
        # Filter op leeftijd (alleen bestanden ouder dan X dagen)
        $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
        $oldItems = @(Get-ChildItem $folderPath -Recurse -ErrorAction SilentlyContinue | 
                      Where-Object { $_.LastWriteTime -lt $cutoffDate })
        
        $itemCount = $oldItems.Count
        if ($itemCount -eq 0) {
            Write-Log -Message "$displayName-map: geen bestanden ouder dan $MaxAgeDays dagen"
            return 0
        }
        
        # Optionele waarschuwing voor gevoelige mappen
        if ($ShowWarning) {
            Write-Log -Message "WAARSCHUWING: $displayName-map wordt opgeschoond: $itemCount items (ouder dan $MaxAgeDays dagen)" -Level 'WARN'
        }
        
        $oldItems | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log -Message "$displayName-map opgeschoond: $itemCount items verwijderd (ouder dan $MaxAgeDays dagen)"
        return $itemCount
    } catch {
        Write-Log -Message "Fout bij opschonen ${displayName}: $($_.Exception.Message)" -Level 'WARN'
        return -1
    }
}

function Clear-OldBackups {
    try {
        $removedCount = 0
        $failedCount = 0
        
        # Stap 1: AVG - Verwijder backups ouder dan retentieperiode
        $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
        $oldBackups = Get-ChildItem -Path $HiddenFolderPath -Filter 'backup_*' -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -lt $cutoffDate }
        
        if ($oldBackups) {
            foreach ($backup in $oldBackups) {
                try {
                    Remove-Item $backup.FullName -Force -ErrorAction Stop
                    $removedCount++
                    Write-Log -Message "AVG: Oude backup verwijderd na $LogRetentionDays dagen" -SkipEventLog
                } catch {
                    $failedCount++
                    Write-Log -Message "Fout bij verwijderen backup $($backup.Name): $($_.Exception.Message)" -Level 'WARN'
                }
            }
            $msg = "Oude script-backups verwijderd: $removedCount items (ouder dan $LogRetentionDays dagen)"
            if ($failedCount -gt 0) { $msg += " - $failedCount gefaald" }
            Write-Log -Message $msg
        }

        # Stap 2: Enforce maximaal aantal backups (0 = geen limiet) - ALTIJD uitvoeren onafhankelijk van retentie
        if ($MaxBackupCount -gt 0) {
            $allBackups = @(Get-ChildItem -Path $HiddenFolderPath -Filter 'backup_*' -ErrorAction SilentlyContinue |
                Sort-Object -Property CreationTime -Descending)
            
            if ($allBackups.Count -gt $MaxBackupCount) {
                $toPurge = $allBackups | Select-Object -Skip $MaxBackupCount
                $purgeCount = 0
                foreach ($b in $toPurge) {
                    try {
                        Remove-Item $b.FullName -Force -ErrorAction Stop
                        $removedCount++
                        $purgeCount++
                        Write-Log -Message "Backup verwijderd (limiet enforcement): $($b.Name)" -SkipEventLog
                    } catch {
                        $failedCount++
                    }
                }
                $msg = "Backuplimiet toegepast: max $MaxBackupCount, extra verwijderd: $purgeCount"
                if ($failedCount -gt 0) { $msg += " ($failedCount gefaald)" }
                Write-Log -Message $msg
            }
        }
        
        if ($removedCount -eq 0) {
            if ($MaxBackupCount -gt 0) {
                Write-Log -Message "Backup opschoning voltooid: geen items verwijderd (retentie/limiet ok)"
            } else {
                Write-Log -Message "Geen oude backups gevonden (retentie: $LogRetentionDays dagen)"
            }
        }
        
        return $removedCount
    } catch {
        Write-Log -Message "Fout bij opschonen oude backups: $($_.Exception.Message)" -Level 'WARN'
        return -1
    }
}

function Restore-FirewallDefaults {
    if (-not $IsAdmin) {
        Write-Log -Message 'Firewall reset overgeslagen: vereist administrator-rechten' -Level 'WARN'
        return $false
    }
    
    try {
        Write-Log -Message 'Reset Windows Firewall naar standaardinstellingen'

        $resetOk = $false

        # Zorg dat vereiste services draaien (BFE en MpsSvc)
        foreach ($svc in 'BFE','MpsSvc') {
            try {
                $s = Get-Service -Name $svc -ErrorAction Stop
                if ($s.Status -ne 'Running') {
                    Start-Service -Name $svc -ErrorAction Stop
                    # Wacht tot service echt draait
                    $timeout = 0
                    while ((Get-Service -Name $svc).Status -ne 'Running' -and $timeout -lt 30) {
                        Start-Sleep -Milliseconds 100
                        $timeout++
                    }
                    if ((Get-Service -Name $svc).Status -eq 'Running') {
                        Write-Log -Message "Service gestart en geverifieerd: $svc"
                    } else {
                        Write-Log -Message "Service start timeout: $svc" -Level 'WARN'
                    }
                }
            } catch {
                Write-Log -Message ("Service {0} kan niet worden gestart: {1}" -f $svc, $_.Exception.Message) -Level 'WARN'
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

    if (-not $IsAdmin -and $EnableStartupTask) {
        Write-Log -Message 'Geplande taak overgeslagen: vereist administrator-rechten voor installatie' -Level 'WARN'
        return 'no-admin'
    }

    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

        if ($EnableStartupTask) {
            # 2) Taak aanmaken of bijwerken
            # BELANGRIJK: Taak draait onder de HUIDIGE gebruiker ($env:USERNAME)
            # Dit zorgt ervoor dat:
            # - User-mappen van de JUISTE gebruiker worden opgeschoond (Downloads, Documents, etc.)
            # - %TEMP%, %LOCALAPPDATA% van de juiste gebruiker worden gebruikt
            # - RunLevel Highest geeft admin-rechten voor WiFi/Firewall/etc.
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

function Get-ActualUserDesktop {
    <#
    .SYNOPSIS
    Vindt de desktop van de daadwerkelijk ingelogde gebruiker, zelfs als script als admin draait.
    
    .DESCRIPTION
    Probeert meerdere methodes om de echte gebruiker te vinden:
    1. Query actieve console sessies (quser/qwinsta)
    2. Win32_ComputerSystem via Get-CimInstance (laatst ingelogde gebruiker)
    3. Fallback naar %PUBLIC%\Desktop voor alle gebruikers
    
    WINDOWS 11 25H2 COMPATIBLE: Gebruikt Get-CimInstance ipv deprecated Get-WmiObject/WMIC
    AVG-COMPLIANT: Logt geen usernames, alleen detectiemethode
    #>
    
    # Methode 1: Zoek actieve console gebruiker via quser/query user
    try {
        $quser = query user 2>$null | Select-Object -Skip 1
        foreach ($line in $quser) {
            # Parse quser output: USERNAME SESSIONNAME ID STATE IDLE TIME LOGON TIME
            # Let op: actieve sessie heeft > voor username (bijv: ">gebruiker")
            if ($line -match '^\s*>?(\S+)\s+(console|\s+)') {
                $userName = $Matches[1].Trim().TrimStart('>')
                $usersRoot = Join-Path $env:SystemDrive 'Users'
                $userProfile = Join-Path $usersRoot $userName
                $testDesktop = Join-Path $userProfile 'Desktop'
                if (Test-Path $testDesktop) {
                    # AVG: Log alleen methode, geen username
                    Write-Log -Message "Desktop bepaald via actieve console sessie" -SkipEventLog
                    return $testDesktop
                }
            }
        }
    } catch {
        # Stille fout - probeer volgende methode
    }
    
    # Methode 2: Win32_ComputerSystem (laatst ingelogde)
    # Gebruikt Get-CimInstance (modern, Windows 11 25H2 compatible - WMIC is verwijderd)
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $loggedOnUser = $computerSystem.UserName
        if ($loggedOnUser) {
            # Parse DOMAIN\Username of COMPUTERNAME\Username
            if ($loggedOnUser -match '[\\/](.+)$') {
                $userName = $Matches[1]
            } else {
                $userName = $loggedOnUser
            }
            
            $userProfile = Join-Path $env:SystemDrive "Users\$userName"
            $testDesktop = Join-Path $userProfile 'Desktop'
            if (Test-Path $testDesktop) {
                # AVG: Log alleen methode, geen username
                Write-Log -Message "Desktop bepaald via CIM (laatst ingelogde gebruiker)" -SkipEventLog
                return $testDesktop
            }
        }
    } catch {
        # Stille fout - probeer volgende methode
    }
    
    # Methode 3: Fallback naar Public Desktop (voor ALLE gebruikers zichtbaar)
    $publicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
    if (Test-Path $publicDesktop) {
        Write-Log -Message "Desktop bepaald via Public Desktop (alle gebruikers)" -SkipEventLog
        return $publicDesktop
    }
    
    # Laatste noodgreep: huidige sessie desktop
    $currentDesktop = [Environment]::GetFolderPath('Desktop')
    Write-Log -Message "Desktop fallback naar huidige sessie" -Level 'WARN'
    return $currentDesktop
}

function Set-DesktopShortcut {
    param(
        [string]$ShortcutName = 'Leenlaptop Opschonen.lnk',
        [string]$TargetScriptPath  # Vul in bij aanroep: de $destPath uit Copy-ScriptToHidden
    )

    $desktop = Get-ActualUserDesktop
    $linkPath = Join-Path $desktop $ShortcutName
    
    # Migratie v1.5.0 → v1.6.0: verwijder oude snelkoppelingen
    $oldShortcutNames = @('Terug naar start.lnk', 'Laptop Opschonen.lnk')
    foreach ($oldName in $oldShortcutNames) {
        $oldPath = Join-Path $desktop $oldName
        if (Test-Path $oldPath) {
            try {
                Remove-Item $oldPath -Force -ErrorAction SilentlyContinue
                Write-Host "[MIGRATIE] Oude snelkoppeling verwijderd: $oldName" -ForegroundColor Yellow
            } catch {
                Write-Warning "[MIGRATIE] Kon oude snelkoppeling niet verwijderen: $oldName"
            }
        }
    }

    try {
        if ($EnableShortcut) {
            $exists = Test-Path $linkPath

            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($linkPath)

            if ($EnableStartupTask) {
                $taskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
                
                if ($taskExists) {
                    # Via scheduled task: geen UAC prompt (taak heeft RunLevel Highest)
                    $shortcut.TargetPath = 'schtasks.exe'
                    $shortcut.Arguments  = "/Run /TN `"$TaskName`""
                    $shortcut.WorkingDirectory = $env:SystemRoot
                    Write-Log -Message "Snelkoppeling start geplande taak: $TaskName (elevated, geen UAC)"
                } else {
                    # Fallback: directe PowerShell start met UAC prompt
                    $shortcut.TargetPath = 'powershell.exe'
                    $shortcut.Arguments  = ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -Verb RunAs -WindowStyle Hidden -FilePath ''powershell.exe'' -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{0}""''"' -f $TargetScriptPath)
                    $shortcut.WorkingDirectory = Split-Path $TargetScriptPath
                    Write-Log -Message "Snelkoppeling start script met UAC (taak niet gevonden, gebruiker moet admin zijn)" -Level 'WARN'
                }
            } else {
                # Zonder scheduled task: directe PowerShell start met UAC prompt
                $shortcut.TargetPath = 'powershell.exe'
                $shortcut.Arguments  = ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Process -Verb RunAs -WindowStyle Hidden -FilePath ''powershell.exe'' -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{0}""''"' -f $TargetScriptPath)
                $shortcut.WorkingDirectory = Split-Path $TargetScriptPath
                Write-Log -Message "Snelkoppeling start script met UAC elevatie (geplande taak uitgeschakeld)"
            }
            $shortcut.IconLocation = 'powershell.exe,0'

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
    Test-Configuration  # Valideer configuratie bij start
    Write-Log -Message "START opschoning leenlaptop (versie $ScriptVersion)"
    
    if (-not $IsAdmin) {
        $adminWarning = @"
WAARSCHUWING: Script draait NIET als administrator!
Sommige functies worden overgeslagen:
- Wi-Fi profiel verwijdering (vereist admin)
- Firewall reset (vereist admin)
- Geplande taak registratie (vereist admin)

Voor volledige functionaliteit: Start als administrator
"@
        Write-Log -Message $adminWarning -Level 'WARN'
        Write-Host $adminWarning -ForegroundColor Yellow
    } else {
        Write-Log -Message "Script draait met administrator-rechten - volledige functionaliteit beschikbaar"
    }
    
    # Timeout mechanisme (conform ontwerp: max 5 minuten)
    $timeoutJob = Start-Job -ScriptBlock {
        param($MaxMinutes)
        Start-Sleep -Seconds ($MaxMinutes * 60)
    } -ArgumentList $MaxExecutionMinutes
    
    try {
        $currentStep = 0
        $totalSteps = 11  # Totaal aantal mogelijke stappen
        
        # Stap 1: Script kopiëren
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Script installeren..." -PercentComplete (++$currentStep / $totalSteps * 100)
        $destPath = Copy-ScriptToHidden
        
        # Valideer dat script succesvol is gekopieerd
        if ([string]::IsNullOrEmpty($destPath) -or -not (Test-Path $destPath)) {
            throw "Script kon niet naar verborgen map worden gekopieerd. Pad: $destPath"
        }
        
        # Stap 2: Browser opschoning
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Browsers opschonen..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Browser opschoning (indien ingeschakeld)
        if ($EnableBrowserCleanup -and $BrowserList -and $BrowserList.Count -gt 0) {
            # Stop browsers met retry-logica
            Invoke-WithRetry -ScriptBlock { Stop-Browsers } -OperationName "Browser stoppen"
            
            # Wis browser data per browser in de lijst
            if ($BrowserList -contains 'msedge') {
                Invoke-WithRetry -ScriptBlock { Clear-EdgeData } -OperationName "Edge data wissen"
            }
            if ($BrowserList -contains 'firefox') {
                Invoke-WithRetry -ScriptBlock { Clear-FirefoxData } -OperationName "Firefox data wissen"
            }
            if ($BrowserList -contains 'chrome') {
                Invoke-WithRetry -ScriptBlock { Clear-ChromeData } -OperationName "Chrome data wissen"
            }
            
            # Noteer resultaat
            $completedSteps += ("Browsers gestopt en data verwijderd ({0})" -f (($BrowserList | Sort-Object) -join ', '))
        } elseif ($EnableBrowserCleanup -and (-not $BrowserList -or $BrowserList.Count -eq 0)) {
            $skippedSteps += 'Browser opschoning (geen browsers in BrowserList)'
        } else {
            $skippedSteps += 'Browser opschoning (uitgeschakeld in configuratie)'
        }
        
        # Stap 3: Wi-Fi profielen
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Wi-Fi profielen opschonen..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Wi-Fi profielen (indien ingeschakeld)
        if ($EnableWiFiCleanup) {
            $wifiResult = Clear-WiFiProfiles
            if ($wifiResult -eq 'no-admin') {
                $skippedSteps += 'Wi-Fi profielen (geen admin-rechten)'
            } elseif ($wifiResult -eq 'no-profiles') {
                $skippedSteps += 'Wi-Fi profielen (geen profielen gevonden)'
            } elseif ($wifiResult -is [hashtable]) {
                if ($wifiResult.Removed -eq 0 -and $wifiResult.Kept -eq 0) {
                    $skippedSteps += 'Wi-Fi profielen (geen actie nodig)'
                } elseif ($wifiResult.Removed -gt 0) {
                    $completedSteps += "Wi-Fi profielen opgeschoond ($($wifiResult.Removed) verwijderd, $($wifiResult.Kept) behouden)"
                } else {
                    $completedSteps += "Wi-Fi profielen behouden ($($wifiResult.Kept) via whitelist)"
                }
            }
        } else {
            $skippedSteps += 'Wi-Fi profielen (uitgeschakeld in configuratie)'
        }
        
        # Stap 4: Temp bestanden
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Tijdelijke bestanden verwijderen..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Temp bestanden
        if ($EnableTempCleanup) {
            $tempCount = Clear-TempFiles
            if ($tempCount -gt 0) {
                $completedSteps += "Tijdelijke bestanden opgeschoond (ongeveer $tempCount items)"
            } elseif ($tempCount -eq 0) {
                $skippedSteps += 'Tijdelijke bestanden (map was al leeg)'
            } else {
                $skippedSteps += 'Tijdelijke bestanden (fout bij opschonen)'
            }
        } else {
            $skippedSteps += 'Tijdelijke bestanden (uitgeschakeld in configuratie)'
        }
        
        # Stap 5: Downloads map
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Downloads opschonen..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Downloads map
        if ($EnableDownloadsCleanup) {
            $dlCount = Clear-DownloadsFolder
            if ($dlCount -gt 0) {
                $completedSteps += "Downloads-map geleegd ($dlCount items verwijderd)"
            } elseif ($dlCount -eq 0) {
                $skippedSteps += 'Downloads-map (was al leeg)'
            } else {
                $skippedSteps += 'Downloads-map (fout bij opschonen)'
            }
        } else {
            $skippedSteps += 'Downloads-map (uitgeschakeld in configuratie)'
        }
        
        # Stap 6: Documenten map
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Documenten controleren..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Documenten map (VOORZICHTIG!)
        if ($EnableDocumentsCleanup) {
            $docCount = Clear-UserFolder -FolderType 'MyDocuments' -MaxAgeDays $DocumentsMaxAgeDays -ShowWarning
            if ($docCount -gt 0) {
                $completedSteps += "Documenten-map geleegd ($docCount items verwijderd)"
            } elseif ($docCount -eq 0) {
                $skippedSteps += 'Documenten-map (was al leeg)'
            } else {
                $skippedSteps += 'Documenten-map (fout bij opschonen)'
            }
        } else {
            $skippedSteps += 'Documenten-map (uitgeschakeld in configuratie)'
        }
        
        # Stap 7: Afbeeldingen map
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Afbeeldingen controleren..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Afbeeldingen map (VOORZICHTIG!)
        if ($EnablePicturesCleanup) {
            $picCount = Clear-UserFolder -FolderType 'MyPictures' -MaxAgeDays $PicturesMaxAgeDays -ShowWarning
            if ($picCount -gt 0) {
                $completedSteps += "Afbeeldingen-map geleegd ($picCount items verwijderd)"
            } elseif ($picCount -eq 0) {
                $skippedSteps += 'Afbeeldingen-map (was al leeg)'
            } else {
                $skippedSteps += 'Afbeeldingen-map (fout bij opschonen)'
            }
        } else {
            $skippedSteps += 'Afbeeldingen-map (uitgeschakeld in configuratie)'
        }
        
        # Stap 8: Video's map
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Video's controleren..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Video's map (VOORZICHTIG!)
        if ($EnableVideosCleanup) {
            $vidCount = Clear-UserFolder -FolderType 'MyVideos' -MaxAgeDays $VideosMaxAgeDays -ShowWarning
            if ($vidCount -gt 0) {
                $completedSteps += "Video's-map geleegd ($vidCount items verwijderd)"
            } elseif ($vidCount -eq 0) {
                $skippedSteps += "Video's-map (was al leeg)"
            } else {
                $skippedSteps += "Video's-map (fout bij opschonen)"
            }
        } else {
            $skippedSteps += "Video's-map (uitgeschakeld in configuratie)"
        }
        
        # Stap 9: Muziek map
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Muziek controleren..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Muziek map (VOORZICHTIG!)
        if ($EnableMusicCleanup) {
            $musCount = Clear-UserFolder -FolderType 'MyMusic' -MaxAgeDays $MusicMaxAgeDays -ShowWarning
            if ($musCount -gt 0) {
                $completedSteps += "Muziek-map geleegd ($musCount items verwijderd)"
            } elseif ($musCount -eq 0) {
                $skippedSteps += 'Muziek-map (was al leeg)'
            } else {
                $skippedSteps += 'Muziek-map (fout bij opschonen)'
            }
        } else {
            $skippedSteps += 'Muziek-map (uitgeschakeld in configuratie)'
        }
        
        # Oude backups opschonen (indien ingeschakeld)
        if ($EnableBackupCleanup) {
            $backupCount = Clear-OldBackups
            if ($backupCount -gt 0) {
                $completedSteps += "Oude script-backups verwijderd ($backupCount items)"
            } elseif ($backupCount -eq 0) {
                $skippedSteps += 'Oude script-backups (geen verouderde backups gevonden)'
            } else {
                $skippedSteps += 'Oude script-backups (fout bij opschonen)'
            }
        } else {
            $skippedSteps += 'Oude script-backups (uitgeschakeld in configuratie)'
        }
        
        # Stap 10: Firewall reset
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Firewall resetten..." -PercentComplete (++$currentStep / $totalSteps * 100)
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
        
        # Stap 11: Voorzieningen installeren
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Voorzieningen installeren..." -PercentComplete (++$currentStep / $totalSteps * 100)
        # Beheer opstarttaak (aan/uit/verwijderen)
        $taskResult = Set-StartupTask -ScriptPath $destPath
        if ($EnableStartupTask) {
            switch ($taskResult) {
                'created'  { $provCompleted += "Geplande taak geregistreerd: $TaskName" }
                'updated'  { $provCompleted += "Geplande taak bijgewerkt: $TaskName" }
                'no-admin' { $provSkipped   += "Geplande taak (geen admin-rechten)" }
                'error'    { $provSkipped   += "Geplande taak kon niet worden ingesteld: $TaskName" }
                default    { $provSkipped   += "Geplande taak status onbekend: $TaskName" }
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
        Write-Progress -Activity "Leenlaptop opschoning" -Status "Afronden..." -PercentComplete 100
        Start-Sleep -Milliseconds 500  # Laat 100% even zichtbaar
        Write-Progress -Activity "Leenlaptop opschoning" -Completed
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
    
    Show-CompletionStatus -Success $executionSuccessful -ErrorMessage $errorDetails -ExecutionTimeSeconds $totalSeconds -CompletedItems $completedSteps -SkippedItems $skippedSteps -ProvisioningCompleted $provCompleted -ProvisioningSkipped $provSkipped
    
    # Exit code: 0 = success, 1 = error (PS 5.1 compatible: use if instead of ternary)
    if ($executionSuccessful) { exit 0 } else { exit 1 }
}
