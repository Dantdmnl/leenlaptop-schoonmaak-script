# leenlaptop-schoonmaak-script

## Overzicht
Dit PowerShell-script is ontworpen om de opschoning en herconfiguratie van leenlaptops te automatiseren. Bij elke gebruikersaanmelding zorgt het script ervoor dat de laptop in een schone en gestandaardiseerde staat verkeert.

## Belangrijkste functies
- **Intelligente zelfupdate** met automatische versiecontrole en backup-systeem
- Zelfkopiëren naar een verborgen map (%LOCALAPPDATA%\HiddenScripts)
- Sluiten van browsers (Edge, Firefox, Chrome) met retry-mechanisme
- Verwijderen van browserdata: cache, cookies, sessies en geschiedenis
- Verwijderen van Wi-Fi-profielen, behalve toegestane netwerken (configureerbaar)
- Leegmaken van tijdelijke bestanden
- Herstellen van Windows Firewall naar standaardinstellingen
- **Automatisch onderhoud**: opschonen van oude backups en logs (30+ dagen)
- **Robuuste foutafhandeling** met retry-logica voor kritieke operaties
- Uitgebreide logging naar zowel bestand als Windows Event Log
- Registreren als geplande taak bij gebruikerslogon
- Bureaubladsnelkoppeling: 'Terug naar start' (configureerbaar)

## Voorwaarden
- Windows 10 of hoger
- PowerShell 5.1 of hoger
- **Aanbevolen uitvoeringsbeleid**: 'RemoteSigned' (veiliger dan Bypass)
- Administratorrechten voor eerste installatie
- Gebruikersaccount met rechten om geplande taken aan te maken

## Installatie-instructies
1. Plaats 'opstart-script.ps1' en 'initial-setup.bat' in dezelfde map.
2. **Klik rechts** op 'initial-setup.bat' en kies **"Als administrator uitvoeren"**.
3. Het verbeterde batch-script controleert automatisch:
   - Administratorrechten
   - PowerShell-beschikbaarheid  
   - Bestandslocaties
4. Het script registreert zichzelf als geplande taak en installeert in verborgen locatie.

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
[bool] $EnableShortcut      = $true               # 🖱️ Bureaubladsnelkoppeling
[bool] $EnableFirewallReset = $true               # 🔥 Windows Firewall reset
[bool] $ForceUpdate         = $false              # 🔄 Forceer script update
```

### 📊 **Performance & Limits**
```powershell
[int]  $MaxLogSizeMB        = 5                   # 📝 Max logbestand grootte (MB)
[int]  $MaxRetries          = 3                   # 🔁 Max herhaalpogingen
[string]$ScriptVersion      = '1.4.0'             # 📋 Huidige versie
```


## 📂 **Bestandslocaties**

| Type | Locatie | Beschrijving |
|------|---------|--------------|
| 📝 **Hoofdlog** | `%LOCALAPPDATA%\HiddenScripts\script.log` | Actuele loguitvoer |
| 📚 **Gearchiveerd** | `script_YYYYMMDD_HHMMSS.log` | Oude logs (auto-rotatie) |
| 🏷️ **Versiebestand** | `version.txt` | Geïnstalleerde scriptversie |
| 💾 **Backups** | `backup_YYYYMMDD_HHMMSS_*.ps1` | Script backups |
| 🖱️ **Snelkoppeling** | `%USERPROFILE%\Desktop\Terug naar start.lnk` | Desktop shortcut |

## 📊 **Logging & Monitoring**

### Log Niveaus
- `[INFO]` - Normale operaties en status updates
- `[WARN]` - Waarschuwingen, niet-kritieke fouten  
- `[ERROR]` - Kritieke fouten die aandacht vereisen

### Event Log Integratie
Het script schrijft naar **Windows Application Log** met bron `OpstartScript`:
```
Event Viewer → Windows Logs → Application → Filter op bron 'OpstartScript'
```

## 🛠️ **Troubleshooting Guide**

| Probleem | Oplossing |
|----------|-----------|
| 🚫 **Script start niet** | Controleer admin-rechten en ExecutionPolicy |
| ⚠️ **Browsers niet gesloten** | Zet `$MaxRetries` hoger of herstart handmatig |
| 📝 **Geen logs** | Controleer schrijfrechten in `%LOCALAPPDATA%` |
| 🔄 **Update werkt niet** | Zet `$ForceUpdate = $true` tijdelijk |
| 📅 **Geplande taak faalt** | Herregistreer taak als administrator |

### Quick Diagnostics
```powershell
# Controleer script status
Get-ScheduledTask -TaskName "Opstart-Script"

# Bekijk recent logs  
Get-Content "$env:LOCALAPPDATA\HiddenScripts\script.log" -Tail 20

# Controleer Event Log
Get-EventLog -LogName Application -Source "OpstartScript" -Newest 10
```

## 📋 **Versie-informatie**

**Huidige versie**: `1.4.0` (30 september 2025)  
**Compatibiliteit**: Automatische upgrade van alle vorige versies  
**Minimum vereisten**: Windows 10, PowerShell 5.1

---

### 🚀 **Snel aan de slag**
1. Download beide bestanden (`opstart-script.ps1` + `initial-setup.bat`)
2. Rechtermuisklik op `initial-setup.bat` → **"Als administrator uitvoeren"**  
3. Script installeert zichzelf en start bij elke gebruikerslogon
4. Klaar! 🎉

> **💡 Tip**: Gebruik de "Terug naar start" snelkoppeling op het bureaublad om het script handmatig uit te voeren.
