# leenlaptop-schoonmaak-script

## Overzicht
Dit PowerShell-script is ontworpen om de opschoning en herconfiguratie van leenlaptops te automatiseren. Het script zorgt ervoor dat apparaten na terugkomst snel en veilig worden teruggebracht naar een schone, gestandaardiseerde staat zonder persoonlijke data of sessies.

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
| 🔒 **Toegang** | Alleen ICT-medewerkers (via NTFS-rechten op %LOCALAPPDATA%) |
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
- **Intelligente zelfupdate** met automatische versiecontrole en backup-systeem
- Zelfkopiëren naar een verborgen map (%LOCALAPPDATA%\HiddenScripts)
- Sluiten van browsers (Edge, Firefox, Chrome) met retry-mechanisme
- Verwijderen van browserdata: cache, cookies, sessies en geschiedenis
- Verwijderen van Wi-Fi-profielen, behalve toegestane netwerken (whitelist)
- Leegmaken van tijdelijke bestanden
- Herstellen van Windows Firewall naar standaardinstellingen (optioneel)
- **🔐 AVG-compliant**: Minimale PII-logging, automatische 30-dagen retentie
- **Automatisch onderhoud**: opschonen van oude backups en logs
- **Robuuste foutafhandeling** met retry-logica voor kritieke operaties
- Uitgebreide logging naar zowel bestand als Windows Event Log (gefilterd)
- **Smart configuratie**: Opstarttaak en snelkoppeling met auto-cleanup
- **Flexibele deployment**: Volledig configureerbare functionaliteit

## Voorwaarden
- Windows 10 of hoger
- PowerShell 5.1 of hoger
- **Aanbevolen uitvoeringsbeleid**: 'RemoteSigned' (veiliger dan Bypass)
- Administratorrechten voor eerste installatie
- Minimaal 5 MB vrije schijfruimte in %LOCALAPPDATA%

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
[string]$HiddenFolderName   = 'HiddenScripts'     # Naam van verborgen map
[string]$TaskName           = 'Opstart-Script'    # Naam geplande taak
[string]$LogFileName        = 'script.log'        # Naam logbestand
[string]$EventSource        = 'OpstartScript'     # Windows Event Log bron
```

### 🌐 **Netwerk & Browsers**
```powershell
[string[]]$AllowedWiFi      = @('uw-wifi')        # Toegestane WiFi-netwerken
[string[]]$BrowserList      = @('msedge','firefox','chrome')  # Te sluiten browsers
```

### 🔧 **Functionaliteit Switches**
```powershell
[bool] $EnableShortcut      = $true               # 🖱️ Bureaubladsnelkoppeling (aan/uit + cleanup)
[bool] $EnableStartupTask   = $true               # ⚡ Opstarttaak registreren (aan/uit + cleanup)
[bool] $EnableFirewallReset = $true               # 🔥 Windows Firewall reset
[bool] $ForceUpdate         = $false              # 🔄 Forceer script update
```

### 📊 **Performance & Limits**
```powershell
[int]  $MaxLogSizeMB        = 5                   # 📝 Max logbestand grootte (MB)
[int]  $MaxRetries          = 3                   # 🔁 Max herhaalpogingen
[int]  $MaxExecutionMinutes = 5                   # ⏱️ Max uitvoeringstijd (ontwerp-eis)
[int]  $LogRetentionDays    = 30                  # 🔐 AVG: Log retentie in dagen
[string]$ScriptVersion      = '1.5.0'             # 📋 Huidige versie
```


## 📂 **Bestandslocaties**

| Type | Locatie | Beschrijving |
|------|---------|--------------|
| 📝 **Hoofdlog** | `%LOCALAPPDATA%\HiddenScripts\script.log` | Actuele loguitvoer (AVG-conform) |
| 📚 **Gearchiveerd** | `script_YYYYMMDD_HHMMSS.log` | Oude logs (auto-rotatie, 30d retentie) |
| 📋 **Status** | `laatste_status.txt` | Laatste SUCCES/FAIL status voor servicedesk |
| 🏷️ **Versiebestand** | `version.txt` | Geïnstalleerde scriptversie |
| 💾 **Backups** | `backup_YYYYMMDD_HHMMSS_*.ps1` | Script backups (30d retentie) |
| 🖱️ **Snelkoppeling** | `%USERPROFILE%\Desktop\Terug naar start.lnk` | Desktop shortcut |

**🔒 Toegangsbeveiliging**: Alle bestanden in verborgen map, alleen toegankelijk voor lokale gebruiker en ICT-admins.

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
Tijdstip: 2025-10-23 14:30:15
Versie: 1.5.0
Uitvoeringstijd: 43.2 seconden

+ Browsers gestopt en data verwijderd
+ Tijdelijke bestanden opgeschoond
+ Wi-Fi profielen gefilterd (whitelist actief)
+ Firewall gereset naar standaardinstellingen

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
Het script schrijft naar **Windows Application Log** met bron `OpstartScript`:
```powershell
# Bekijk events (gefilterd voor privacy)
Get-EventLog -LogName Application -Source "OpstartScript" -Newest 10
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
Get-Content "$env:LOCALAPPDATA\HiddenScripts\script.log" -Tail 20

# Controleer laatste status voor servicedesk
Get-Content "$env:LOCALAPPDATA\HiddenScripts\laatste_status.txt"

# Controleer Event Log (alleen niet-PII entries)
Get-EventLog -LogName Application -Source "OpstartScript" -Newest 10
```

## 📋 **Versie-informatie**

**Huidige versie**: `1.5.0` (23 oktober 2025)  
**Wijzigingen t.o.v. 1.4.1**:
- ✅ **AVG-compliance**: Geen PII in logs (usernames, netwerknamen verwijderd)
- ✅ **Automatische logretentie**: 30 dagen conform wetgeving
- ✅ **Status voor servicedesk**: Duidelijke SUCCES/FAIL meldingen
- ✅ **Timeout controle**: Maximum 5 minuten uitvoeringstijd
- ✅ **Verbeterde privacy**: Event Log filtering voor gevoelige data
- ✅ **Ontwerp-conformiteit**: Volledig conform technisch ontwerp MBO Rijnstad

**Compatibiliteit**: Automatische upgrade van alle vorige versies  
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
