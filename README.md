# leenlaptop-schoonmaak-script

PowerShell-script voor het opschonen en opnieuw standaardiseren van leenlaptops na gebruik. Het script verwijdert lokale sporen van de vorige gebruiker, legt een beperkte operationele audit trail vast en geeft na afloop een duidelijke status voor servicedesk of ICT-beheer.

**Versie:** 1.6.3
**Release datum:** 2 juli 2026
**Platform:** Windows 10/11, PowerShell 5.1 of hoger

## Doel

Dit project is bedoeld voor organisaties die leenlaptops opnieuw willen uitgeven zonder een volledige herinstallatie of centraal beheersysteem als harde voorwaarde. De oplossing draait lokaal, is via configuratie aan te passen en houdt rekening met AVG-uitgangspunten zoals dataminimalisatie en beperkte logretentie.

## Functionaliteit

- Sluit browsers en verwijdert browserdata voor Edge, Chrome en Firefox.
- Verwijdert Wi-Fi-profielen, met optionele whitelist voor toegestane netwerken.
- Verwijdert tijdelijke bestanden en oude bestanden uit Downloads.
- Kan Documenten, Afbeeldingen, Video's en Muziek opschonen, maar deze opties staan standaard uit.
- Reset Windows Firewall naar standaardinstellingen.
- Installeert zichzelf in `C:\ProgramData\LeenlaptopSchoonmaak`.
- Registreert een geplande taak en maakt een bureaubladsnelkoppeling aan.
- Roteert logs en verwijdert oude logs/backups volgens retentie-instellingen.
- Schrijft een laatste status naar `laatste_status.txt`.

## Privacy en logging

Het script logt alleen operationele informatie die nodig is voor controle en troubleshooting:

- tijdstip van uitvoering;
- uitgevoerde acties;
- aantallen verwijderde items;
- foutmeldingen en statuscodes;
- scriptversie.

Het script logt geen gebruikersnamen, bestandsnamen, browsergeschiedenis, IP-adressen of Wi-Fi-netwerknamen naar het Windows Event Log. Detailmeldingen die mogelijk herleidbare informatie bevatten, blijven beperkt tot de lokale log en worden waar nodig niet naar Event Log doorgeschreven.

Standaard worden logs en scriptbackups maximaal 30 dagen bewaard.

## Vereisten

- Windows 10 of Windows 11.
- PowerShell 5.1 of hoger.
- Administratorrechten voor installatie, geplande taak, Wi-Fi cleanup en firewall reset.
- Ongeveer 5 MB vrije ruimte onder `C:\ProgramData`.

Het script gebruikt `Get-CimInstance` in plaats van WMIC en is daarmee geschikt voor recente Windows 11-versies waarin WMIC niet meer beschikbaar is.

## Installatie

1. Plaats `Install-LeenlaptopSchoonmaak.bat` en `LeenlaptopSchoonmaak.ps1` in dezelfde map, bijvoorbeeld op een USB-stick of lokale tijdelijke map.
2. Start `Install-LeenlaptopSchoonmaak.bat` met **Als administrator uitvoeren**.
3. Controleer de getoonde configuratie.
4. Bevestig de installatie met `J`.
5. Controleer na afloop:
   - scriptlocatie: `C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1`;
   - taakplanner: taak `LeenlaptopSchoonmaak`;
   - logbestand: `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`;
   - snelkoppeling: `Leenlaptop Opschonen.lnk`.

Handmatige installatie kan ook:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd "D:\pad\naar\script"
.\LeenlaptopSchoonmaak.ps1
```

## Configuratie

Alle instellingen staan bovenin `LeenlaptopSchoonmaak.ps1` in het configuratieblok.

### Basis

```powershell
[string]$HiddenFolderName = 'LeenlaptopSchoonmaak'
[string]$TaskName         = 'LeenlaptopSchoonmaak'
[string]$LogFileName      = 'log.txt'
[string]$EventSource      = 'LeenlaptopSchoonmaak'
[string]$ScriptVersion    = '1.6.3'
```

### Netwerk en browsers

```powershell
[string[]]$AllowedWiFi = @()
[string[]]$BrowserList = @('msedge','firefox','chrome')
```

Gebruik altijd quotes in arrays:

```powershell
[string[]]$AllowedWiFi = @('kantoor-wifi', 'gast-netwerk')
```

Een lege `AllowedWiFi` betekent dat alle gevonden Wi-Fi-profielen worden verwijderd.

### Opschoning

```powershell
[bool] $EnableBrowserCleanup   = $true
[bool] $EnableWiFiCleanup      = $true
[bool] $EnableTempCleanup      = $true
[bool] $EnableDownloadsCleanup = $true
[int]  $DownloadsMaxAgeDays    = 7

[bool] $EnableDocumentsCleanup = $false
[int]  $DocumentsMaxAgeDays    = 30
[bool] $EnablePicturesCleanup  = $false
[int]  $PicturesMaxAgeDays     = 30
[bool] $EnableVideosCleanup    = $false
[int]  $VideosMaxAgeDays       = 30
[bool] $EnableMusicCleanup     = $false
[int]  $MusicMaxAgeDays        = 30

[bool] $EnableFirewallReset    = $true
```

De cleanup van gebruikersmappen verwijdert oude bestanden en ruimt daarna alleen lege oude submappen op. Een oude map met nieuwere bestanden wordt dus niet volledig verwijderd.

### Onderhoud en limieten

```powershell
[int]  $MaxLogSizeMB        = 5
[int]  $LogRetentionDays    = 30
[int]  $MaxRetries          = 3
[int]  $MaxExecutionMinutes = 5
[bool] $EnableBackupCleanup = $true
[int]  $MaxBackupCount      = 5
[bool] $ForceUpdate         = $false
```

Zet `ForceUpdate` alleen tijdelijk op `$true` wanneer een bestaande installatie expliciet overschreven moet worden. De gekopieerde versie zet deze waarde daarna automatisch terug naar `$false`.

## Bestandslocaties

| Type | Locatie |
|------|---------|
| Hoofdlog | `C:\ProgramData\LeenlaptopSchoonmaak\log.txt` |
| Gearchiveerde logs | `C:\ProgramData\LeenlaptopSchoonmaak\script_YYYYMMDD_HHMMSS.log` |
| Laatste status | `C:\ProgramData\LeenlaptopSchoonmaak\laatste_status.txt` |
| Versiebestand | `C:\ProgramData\LeenlaptopSchoonmaak\version.txt` |
| Scriptbackups | `C:\ProgramData\LeenlaptopSchoonmaak\backup_YYYYMMDD_HHMMSS_*.ps1` |
| Snelkoppeling | `%USERPROFILE%\Desktop\Leenlaptop Opschonen.lnk` |

## Controle en troubleshooting

```powershell
Get-ScheduledTask -TaskName "LeenlaptopSchoonmaak"
Get-Content "C:\ProgramData\LeenlaptopSchoonmaak\log.txt" -Tail 50
Get-Content "C:\ProgramData\LeenlaptopSchoonmaak\laatste_status.txt"
Get-EventLog -LogName Application -Source "LeenlaptopSchoonmaak" -Newest 10
```

Veelvoorkomende oorzaken:

| Probleem | Controle |
|----------|----------|
| Script start niet | Administratorrechten, ExecutionPolicy en scriptlocatie controleren |
| Geen logs | Schrijfrechten onder `C:\ProgramData\LeenlaptopSchoonmaak` controleren |
| Wi-Fi cleanup werkt niet | Controleren of de taak met hoogste rechten draait |
| Firewall reset faalt | Beleid, rechten en Windows Firewall-services controleren |
| Timeout | `MaxExecutionMinutes` verhogen of cleanup scope beperken |

## Migratie

Versies vanaf 1.6.0 gebruiken `C:\ProgramData\LeenlaptopSchoonmaak`. Oude installaties op `%LOCALAPPDATA%\HiddenScripts` worden bij herinstallatie automatisch gemigreerd. Daarbij verwijdert het script ook de oude geplande taak `Opstart-Script` en oude snelkoppelingen zoals `Terug naar start.lnk`.

Vanaf 1.6.3 heet het installatiescript `Install-LeenlaptopSchoonmaak.bat` en het PowerShell-script `LeenlaptopSchoonmaak.ps1`. Een oude geinstalleerde `opstart-script.ps1` wordt na een succesvolle kopie van de nieuwe scriptnaam verwijderd.

## Validatie

Voor deze release zijn de volgende controles uitgevoerd:

```powershell
# PowerShell parser
[System.Management.Automation.Language.Parser]::ParseFile(...)

# Configuratie-export
.\LeenlaptopSchoonmaak.ps1 -PrintConfig

# CI-regels uit GitHub workflow
Invoke-ScriptAnalyzer -Path .\LeenlaptopSchoonmaak.ps1 -IncludeRule PSAvoidGlobalAliases,PSAvoidUsingConvertToSecureStringWithPlainText

# Git whitespace check
git diff --check
```

Het volledige opschoonscript is niet automatisch uitgevoerd tijdens validatie, omdat dit echte lokale data en systeeminstellingen kan wijzigen.
