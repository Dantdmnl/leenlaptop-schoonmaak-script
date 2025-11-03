# leenlaptop-schoonmaak-script

## Overzicht
Dit PowerShell-script is ontworpen om de opschoning en herconfiguratie van leenlaptops te automatiseren. Het script zorgt ervoor dat apparaten na terugkomst snel en veilig worden teruggebracht naar een schone, gestandaardiseerde staat zonder persoonlijke data of sessies.

**Versie:** 1.6.0 | **Release datum:** 3 november 2025

## 📋 Ontwerp & Conformiteit
Dit script is ontwikkeld conform een professioneel technisch ontwerp en voldoet aan:
- ✅ **AVG-wetgeving**: Minimale logging van persoonsgegevens, 30 dagen retentie
- ✅ **Functionele eisen**: Volledige opschoning met audit trails en versiecontrole
- ✅ **Niet-functionele eisen**: Windows 10/11, max 5 min uitvoeringstijd, schaalbaar
- ✅ **Acceptatiecriteria**: Duidelijke SUCCES/FAIL status voor servicedesk

## 🔐 AVG & Privacy Compliance

### Gegevensminimalisatie
Het script is ontworpen volgens het **privacy-by-design** principe:
- ❌ **GEEN logging van**: Gebruikersnamen, Wi-Fi netwerknamen, bestandspaden met persoonsgegevens
- ✅ **WEL logging van**: Tijdstempel, operaties, aantallen, foutcodes, versie-info

### Logretentie & Toegangscontrole
| Aspect | Implementatie |
|--------|---------------|
| 📅 **Retentieperiode** | Automatisch 30 dagen (configureerbaar) |
| 🗑️ **Auto-cleanup** | Dagelijkse controle op oude logs en backups |
| 🔒 **Toegang** | Alleen ICT-medewerkers (via NTFS-rechten op C:\ProgramData) |
| 📝 **Event Log** | Gefilterd - alleen niet-PII berichten |

### Privacy-maatregelen in code
```powershell
# Voorbeeld: Browsers stoppen ZONDER username te loggen
$processes | Stop-Process  # Geen filter op username
Write-Log "Browser gestopt: chrome (3 processen)"  # Aantal, geen namen

# Wi-Fi profielen ZONDER netwerknamen in Event Log
Write-Log "Wi-Fi opschoning: 5 verwijderd, 1 behouden" -SkipEventLog
```

## Belangrijkste functies
- **🎯 Duidelijke status voor servicedesk**: SUCCES/FAIL melding na elke opschoning
- **⏱️ Tijdscontrole**: Maximaal 5 minuten uitvoeringstijd (conform ontwerp)
- **🔄 Automatische migratie**: v1.5.0 → v1.6.0 gebeurt automatisch bij herinstallatie
- **Intelligente zelfupdate** met automatische versiecontrole en backup-systeem
- Installatie naar `C:\ProgramData\LeenlaptopSchoonmaak` (systeem-breed, ICT-toegankelijk)
- **🔧 Volledig configureerbaar**: Alle cleanup functies in/uitschakelbaar
- Sluiten van browsers (Edge, Firefox, Chrome) met retry-mechanisme
- Verwijderen van browserdata: cache, cookies, sessies en geschiedenis
- Verwijderen van Wi-Fi-profielen, behalve toegestane netwerken (whitelist)
- **📁 Slimme folder cleanup**: Alleen oude bestanden (Downloads >7 dagen, rest >30 dagen)
- Leegmaken van tijdelijke bestanden met configureerbare leeftijd
- Herstellen van Windows Firewall naar standaardinstellingen
- **🔐 AVG-compliant**: Minimale PII-logging, automatische 30-dagen retentie
- **🛡️ Graceful degradation**: Script werkt ook zonder admin-rechten (beperkte functionaliteit)
- **Automatisch onderhoud**: opschonen van oude backups en logs
- **Robuuste foutafhandeling** met retry-logica voor kritieke operaties
- Uitgebreide logging naar zowel bestand als Windows Event Log (gefilterd)
- **Smart configuratie**: Opstarttaak en snelkoppeling met intelligente elevatie
- **Flexibele deployment**: 10+ configureerbare opties voor verschillende scenario's

## Voorwaarden
- Windows 10 of hoger (inclusief Windows 11 24H2/25H2)
- PowerShell 5.1 of hoger
- **Aanbevolen uitvoeringsbeleid**: 'RemoteSigned' (veiliger dan Bypass)
- Administratorrechten voor eerste installatie (scheduled task, WiFi cleanup, firewall)
- Minimaal 5 MB vrije schijfruimte in `C:\ProgramData`

> **Windows 11 25H2 Compatibiliteit**: Script gebruikt moderne `Get-CimInstance` cmdlet (WMIC is verwijderd in 25H2)

## Installatie-instructies

### 🚀 Snelle Installatie (Aanbevolen)
1. Kopieer **beide bestanden** naar USB-stick of lokale map:
   - `initial-setup.bat`
   - `opstart-script.ps1`
2. **Rechtermuisklik** op `initial-setup.bat` → **"Als administrator uitvoeren"**
3. Het script voert automatisch 5 controles uit:
   - ✓ Administrator rechten
   - ✓ PowerShell versie (min. 5.1)
   - ✓ Script bestanden aanwezig
   - ✓ Schrijfrechten in %LOCALAPPDATA%
   - ✓ Installatie en eerste schoonmaak
4. Wacht tot de melding **"INSTALLATIE SUCCESVOL VOLTOOID"** verschijnt
5. **Klaar!** USB-stick mag worden verwijderd

### 🔧 Handmatige Installatie (Geavanceerd)
Als de automatische installatie niet werkt:
```powershell
# Voer uit als Administrator in PowerShell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
cd "D:\pad\naar\script"  # Pas aan naar jouw locatie
.\opstart-script.ps1
```

### ⚡ Wat doet initial-setup.bat?
Het batch-script voert robuuste pre-flight checks uit:
- Verifieert administrator rechten met duidelijke instructies
- Controleert PowerShell versie (blokkeert bij < 5.1)
- Valideert bestandsintegriteit (grootte, aanwezigheid)
- Test schrijfrechten in doelmap
- Toont real-time voortgang in 5 stappen
- Geeft duidelijke SUCCES/FAIL status met troubleshooting tips
- Optie om logmap direct te openen na installatie

## ⚙️ Configuratie-opties

Het script is volledig configureerbaar via variabelen in het `#region Configuratie` gedeelte van het PowerShell script:

### 📁 **Locatie & Naming**
```powershell
[string]$HiddenFolderName   = 'LeenlaptopSchoonmaak'  # Naam van map in C:\ProgramData
[string]$TaskName           = 'LeenlaptopSchoonmaak'  # Naam geplande taak
[string]$LogFileName        = 'log.txt'               # Naam logbestand
[string]$EventSource        = 'LeenlaptopSchoonmaak'  # Windows Event Log bron
```

> **Migratienotitie**: v1.5.0 gebruikte `%LOCALAPPDATA%\HiddenScripts`. v1.6.0 migreert automatisch naar `C:\ProgramData\LeenlaptopSchoonmaak` bij herinstallatie.

### 🌐 **Netwerk & Browsers**
```powershell
[string[]]$AllowedWiFi      = @()                 # Toegestane WiFi-netwerken (leeg = alles verwijderen)
[string[]]$BrowserList      = @('msedge','firefox','chrome')  # Te sluiten browsers (procesnamen)
```

> **⚠️ BELANGRIJK**: Gebruik altijd **quotes** rond strings in arrays:
> - ✅ **GOED**: `@('kantoor-wifi', 'gast-netwerk')`
> - ❌ **FOUT**: `@(kantoor-wifi)` → crasht script!
> - Lege array `@()` betekent "alles verwijderen" bij WiFi

### 🔧 **Functionaliteit Switches (Voorzieningen)**
```powershell
[bool] $EnableShortcut      = $true               # 🖱️ Bureaubladsnelkoppeling (aan/uit + cleanup)
[bool] $EnableStartupTask   = $true               # ⚡ Opstarttaak registreren (aan/uit + cleanup)
[bool] $ForceUpdate         = $false              # 🔄 Forceer script update
```

### 🧹 **Opschoning Switches (Volledig configureerbaar)**
```powershell
[bool] $EnableBrowserCleanup   = $true            # 🌐 Browsers stoppen en data wissen
[bool] $EnableWiFiCleanup      = $true            # 📡 Wi-Fi profielen opschonen
[bool] $EnableTempCleanup      = $true            # 🗑️ Tijdelijke bestanden verwijderen
[bool] $EnableDownloadsCleanup = $true            # 📥 Downloads-map opschonen (>7 dagen)
[int]  $DownloadsMaxAgeDays    = 7                # 📅 Alleen bestanden ouder dan X dagen
[bool] $EnableDocumentsCleanup = $false           # 📄 Documenten-map opschonen (VOORZICHTIG!)
[int]  $DocumentsMaxAgeDays    = 30               # 📅 Alleen bestanden ouder dan X dagen
[bool] $EnablePicturesCleanup  = $false           # 🖼️ Afbeeldingen-map opschonen (VOORZICHTIG!)
[int]  $PicturesMaxAgeDays     = 30               # 📅 Alleen bestanden ouder dan X dagen
[bool] $EnableVideosCleanup    = $false           # 🎬 Video's-map opschonen (VOORZICHTIG!)
[int]  $VideosMaxAgeDays       = 30               # 📅 Alleen bestanden ouder dan X dagen
[bool] $EnableMusicCleanup     = $false           # 🎵 Muziek-map opschonen (VOORZICHTIG!)
[int]  $MusicMaxAgeDays        = 30               # 📅 Alleen bestanden ouder dan X dagen
[bool] $EnableFirewallReset    = $true            # 🔥 Windows Firewall reset
[bool] $EnableBackupCleanup    = $true            # 🗄️ Oude backups verwijderen (30 dagen)
```

**💡 NIEUW in v1.6.0**: Alle folder cleanup functies gebruiken nu **leeftijdsfiltering**! Alleen bestanden ouder dan X dagen worden verwijderd (niet alles). Downloads standaard 7 dagen, rest 30 dagen.

**⚠️ BELANGRIJK**: Media-mappen (Documenten, Afbeeldingen, Video's, Muziek) staan standaard **UIT** vanwege het risico op dataverlies. Downloads-cleanup is standaard **AAN** (veilig met 7 dagen filter).

### 📊 **Performance & Limits**
```powershell
[int]  $MaxLogSizeMB        = 5                   # 📝 Max logbestand grootte (MB)
[int]  $MaxRetries          = 3                   # 🔁 Max herhaalpogingen
[int]  $MaxExecutionMinutes = 5                   # ⏱️ Max uitvoeringstijd (ontwerp-eis)
[int]  $LogRetentionDays    = 30                  # 🔐 AVG: Log retentie in dagen
[string]$ScriptVersion      = '1.6.0'             # 📋 Huidige versie
```


## 📂 **Bestandslocaties**

| Type | Locatie | Beschrijving |
|------|---------|--------------|
| 📝 **Hoofdlog** | `C:\ProgramData\LeenlaptopSchoonmaak\log.txt` | Actuele loguitvoer (AVG-conform) |
| 📚 **Gearchiveerd** | `log_YYYYMMDD_HHMMSS.txt` | Oude logs (auto-rotatie, 30d retentie) |
| 📋 **Status** | `laatste_status.txt` | Laatste SUCCES/FAIL status voor servicedesk |
| 🏷️ **Versiebestand** | `version.txt` | Geïnstalleerde scriptversie |
| 💾 **Backups** | `backup_YYYYMMDD_HHMMSS_*.ps1` | Script backups (30d retentie) |
| 🖱️ **Snelkoppeling** | `%USERPROFILE%\Desktop\Leenlaptop Opschonen.lnk` | Desktop shortcut |

**🔒 Toegangsbeveiliging**: Alle bestanden in `C:\ProgramData` (verborgen map), alleen toegankelijk voor ICT-admins.

**🔄 Migratienotitie**: v1.5.0 gebruikte `%LOCALAPPDATA%\HiddenScripts`. Script migreert automatisch bij herinstallatie naar nieuwe locatie.

## 📊 **Logging & Monitoring**

### Log Niveaus
- `[INFO]` - Normale operaties en status updates
- `[WARN]` - Waarschuwingen, niet-kritieke fouten  
- `[ERROR]` - Kritieke fouten die aandacht vereisen

### Status Rapportage (conform ontwerp)
Na elke uitvoering toont het script een duidelijke status:

**SUCCES:**
```
===================================================
  OPSCHONING VOLTOOID - APPARAAT KLAAR VOOR UITLEEN
===================================================
Tijdstip: 2025-11-03 14:30:15
Versie: 1.6.0
Uitvoeringstijd: 43.2 seconden

+ Browsers gestopt en data verwijderd (chrome, msedge)
+ Wi-Fi profielen opgeschoond (3 verwijderd, 1 behouden)
+ Tijdelijke bestanden opgeschoond (ongeveer 127 items)
+ Downloads-map opgeschoond: 15 items verwijderd (ouder dan 7 dagen)
- Documenten-map (uitgeschakeld in configuratie)
+ Firewall teruggezet naar standaardinstellingen

Voorzieningen:
+ Geplande taak geregistreerd: LeenlaptopSchoonmaak
+ Snelkoppeling op bureaublad aangemaakt

STATUS: SUCCES - Apparaat is schoon en klaar
===================================================
```

**FAILED:**
```
===================================================
  OPSCHONING MISLUKT - HANDMATIGE INTERVENTIE VEREIST
===================================================
STATUS: FAILED - Meld dit apparaat bij ICT servicedesk
===================================================
```

### Event Log Integratie
Het script schrijft naar **Windows Application Log** met bron `LeenlaptopSchoonmaak`:
```powershell
# Bekijk events (gefilterd voor privacy)
Get-EventLog -LogName Application -Source "LeenlaptopSchoonmaak" -Newest 10
```
**⚠️ AVG-nota**: Event Log bevat GEEN persoonsgegevens - alleen operationele statussen.

## 🛠️ **Troubleshooting Guide**

| Probleem | Oplossing |
|----------|-----------|
| 🚫 **Script start niet** | Controleer admin-rechten en ExecutionPolicy |
| ⚠️ **Browsers niet gesloten** | Zet `$MaxRetries` hoger of herstart handmatig |
| 📝 **Geen logs** | Controleer schrijfrechten in `%LOCALAPPDATA%` |
| 🔄 **Update werkt niet** | Zet `$ForceUpdate = $true` tijdelijk |
| 📅 **Geplande taak faalt** | Herregistreer taak als administrator |
| ⏱️ **Timeout overschreden** | Verhoog `$MaxExecutionMinutes` (standaard 5 min) |
| 🔐 **AVG-audit vragen** | Toon `laatste_status.txt` en logs (max 30 dagen) |

### Quick Diagnostics
```powershell
# Controleer script status
Get-ScheduledTask -TaskName "Opstart-Script"

# Bekijk recent logs (AVG-conform, geen PII)
Get-Content "C:\ProgramData\LeenlaptopSchoonmaak\log.txt" -Tail 50

# Controleer laatste status voor servicedesk
Get-Content "C:\ProgramData\LeenlaptopSchoonmaak\laatste_status.txt"

# Controleer Event Log (alleen niet-PII entries)
Get-EventLog -LogName Application -Source "LeenlaptopSchoonmaak" -Newest 10
```

## 🎯 **Use Cases & Scenario's**

### Scenario 1: Standaard Leenlaptop (Basis) - STANDAARD CONFIGURATIE
**Gebruik**: Korte uitleen (1-7 dagen), kantoorwerk, veilige cleanup
```powershell
$EnableBrowserCleanup   = $true   # Browsers opschonen
$EnableWiFiCleanup      = $true   # Wi-Fi resetten
$EnableTempCleanup      = $true   # Temp wissen
$EnableDownloadsCleanup = $true   # Downloads >7 dagen oud
$DownloadsMaxAgeDays    = 7       # Recent werk blijft behouden
$EnableFirewallReset    = $true   # Firewall naar standaard
# Media-mappen UIT (veilig)
```

### Scenario 2: Evenement/Conferentie Laptop (Agressief)
**Gebruik**: Korte uitleen (1-3 dagen), publiek toegankelijk, hoog risico
```powershell
$EnableBrowserCleanup   = $true
$EnableWiFiCleanup      = $true
$EnableTempCleanup      = $true
$EnableDownloadsCleanup = $true
$DownloadsMaxAgeDays    = 1       # Downloads >1 dag al weg
$EnableDocumentsCleanup = $true   # Documenten >1 dag
$DocumentsMaxAgeDays    = 1
$EnablePicturesCleanup  = $true   # Media >1 dag
$PicturesMaxAgeDays     = 1
$EnableVideosCleanup    = $true
$VideosMaxAgeDays       = 1
$EnableMusicCleanup     = $true
$MusicMaxAgeDays        = 1
$EnableFirewallReset    = $true
# Agressief schoon tussen gebruikers
```

### Scenario 3: Presentatie/Demo Laptop (Selectief)
**Gebruik**: Vaste laptop voor demos, alleen browsing opschonen
```powershell
$EnableBrowserCleanup   = $true   # Browsing geschiedenis wissen
$EnableWiFiCleanup      = $false  # Wi-Fi behouden (bekende netwerken)
$EnableTempCleanup      = $true
$EnableDownloadsCleanup = $false  # Demo bestanden bewaren
$EnableFirewallReset    = $false  # Netwerk-instellingen bewaren
# Media-mappen behouden (demo materiaal)
```

### Scenario 4: Thuiswerk Laptop (Minimaal)
**Gebruik**: Lange uitleen (maanden), vertrouwde gebruikers
```powershell
$EnableBrowserCleanup   = $false  # Browser sessies bewaren
$EnableWiFiCleanup      = $false  # Thuisnetwerken bewaren
$EnableTempCleanup      = $true   # Alleen temp opschonen
$EnableDownloadsCleanup = $true   # Oude downloads (>30 dagen)
$DownloadsMaxAgeDays    = 30      # Ruime marge
$EnableFirewallReset    = $false  # Netwerk-instellingen bewaren
# Alle media-mappen behouden
```

## 📋 **Versie-informatie**

**Huidige versie**: `1.6.0` (3 november 2025)  
**Belangrijkste wijzigingen**:
- 🔄 **Automatische migratie**: Oude installaties (v1.5.0) worden automatisch gemigreerd
- 📁 **Nieuwe locatie**: `C:\ProgramData\LeenlaptopSchoonmaak` (was: `%LOCALAPPDATA%\HiddenScripts`)
- ⏰ **Slimme cleanup**: Leeftijdsfiltering voor alle folder-functies (alleen oude bestanden)
- ✨ **Volledig configureerbaar**: 10+ cleanup-opties individueel aan/uit
- 📁 **Media-mappen**: Afbeeldingen, Video's en Muziek opschoning met leeftijdsfilter
- 🖥️ **Desktop fix**: Snelkoppeling werkt nu correct bij admin-sessies
- 📊 **Betere rapportage**: Duidelijke status per item met aantallen
- 🎯 **Use case support**: 4 vooraf geconfigureerde scenario's
- 🛡️ **Admin handling**: Graceful degradation zonder admin-rechten
- 🔒 **AVG-compliance**: Gebruikerscontext-documentatie, geen PII-logging
- 📖 **Servicedesk handleiding**: Nieuwe SERVICEDESK.md met troubleshooting

**Compatibiliteit**: Automatische migratie van v1.5.0 → v1.6.0 bij herinstallatie  
**Breaking changes**: Paths, task/file namen gewijzigd (zie CHANGELOG.md)  
**Minimum vereisten**: Windows 10, PowerShell 5.1

---

## 🎓 **Ontwerpverantwoording**

Dit script implementeert een **lokaal, laagdrempelig opschoningsproces**:
> *"Direct inzetbaar, laag in kosten, weinig extra infrastructuur, eenvoudig voor servicedesk."*

### Ontwikkelmethode: Scrum
- Iteratieve ontwikkeling in sprints
- Continue evaluatie en verbetering
- Snelle aanpassingen op basis van feedback

### Acceptatiecriteria (VOLDAAN ✅)
- ✅ Geen actieve gebruikerssessies of wachtwoorden na uitvoering
- ✅ Alleen whitelist-netwerken behouden
- ✅ Lokale logs met timestamp en foutmeldingen (30d retentie)
- ✅ Bedienbaar door servicedesk met SUCCES/FAIL status
- ✅ Uitvoeringstijd ≤ 5 minuten met timeout-controle
- ✅ Geen onherstelbare wijzigingen aan apparaat

---

### 🚀 **Snel aan de slag**
1. Download beide bestanden (`opstart-script.ps1` + `initial-setup.bat`)
2. Rechtermuisklik op `initial-setup.bat` → **"Als administrator uitvoeren"**  
3. Script installeert zichzelf en start bij elke gebruikerslogon
4. Klaar! 🎉

> **💡 Tip**: Gebruik de "Terug naar start" snelkoppeling op het bureaublad om het script handmatig uit te voeren.
