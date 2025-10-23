# Changelog - Leenlaptop Opschoningsscript

Alle belangrijke wijzigingen aan dit project worden gedocumenteerd in dit bestand.

---

## [1.5.0] - 2025-10-23

### 🐛 Kritieke Bugfix (pre-release)
- **OPGELOST**: Script verwijderde **altijd** alle browser data (Edge, Firefox, Chrome) ongeacht `$BrowserList` configuratie
- **TOEGEVOEGD**: Conditionale checks voor elke browser: alleen data wissen als browser in `$BrowserList` staat
- **VERBETERD**: Clear-EdgeData, Clear-FirefoxData en Clear-ChromeData worden nu alleen aangeroepen voor geconfigureerde browsers
- **VOORBEELD**: Met `$BrowserList = @('msedge')` wordt nu **alleen** Edge data verwijderd (Firefox en Chrome blijven onaangeroerd)

### 🎯 Dynamische Status & Voorzieningen
- **TOEGEVOEGD**: `Show-CompletionStatus` functie met professionele SUCCES/FAIL meldingen
- **TOEGEVOEGD**: Dynamische completion status met voltooide/overgeslagen items (+/-)
- **TOEGEVOEGD**: "Voorzieningen" sectie in statusweergave voor infrastructuur
- **TOEGEVOEGD**: `laatste_status.txt` bestand voor servicedesk controle
- **TOEGEVOEGD**: Status tracking voor geplande taak (geregistreerd/bijgewerkt/uitgeschakeld)
- **TOEGEVOEGD**: Status tracking voor snelkoppeling (aangemaakt/bijgewerkt/uitgeschakeld)
- **TOEGEVOEGD**: Kleurgecodeerde output (groen=succes, rood=fout)
- **TOEGEVOEGD**: Uitvoeringstijd weergave in statusmelding

### 🔧 Configuratie & Beheer Verbeteringen
- **TOEGEVOEGD**: `$MaxExecutionMinutes` configuratie (standaard 5 minuten)
- **TOEGEVOEGD**: `$LogRetentionDays` configuratie (standaard 30 dagen AVG-compliant)
- **TOEGEVOEGD**: ForceUpdate wordt automatisch gereset naar `$false` in gekopieerde versie
- **TOEGEVOEGD**: Regex-based replace voor ForceUpdate in gekopieerde script
- **VERBETERD**: Voorkomt oneindige update-loops bij gebruik van ForceUpdate
- **TOEGEVOEGD**: Timeout mechanisme met background job (max 5 minuten)
- **TOEGEVOEGD**: Exit code 1 bij fouten voor monitoring/automation

### ⚡ Scheduled Task Optimalisaties
- **AANGEPAST**: ExecutionTimeLimit nu dynamisch afgestemd op MaxExecutionMinutes
- **VERWIJDERD**: 72-uur default ExecutionTimeLimit (onnodig lang)
- **TOEGEVOEGD**: ExecutionTimeLimit = max(MaxExecutionMinutes + 5, 10) minuten
- **OPGELOST**: AllowStartOnDemand parameter verwijderd (PS 5.1 compatibiliteit)
- **TOEGEVOEGD**: Return status voor Set-StartupTask (created/updated/removed/absent/error)
- **VERBETERD**: Idempotente task registratie met -Force parameter
- **HERNOEMT**: `Manage-StartupTask` → `Set-StartupTask` (approved verb)

### 🔥 Firewall Reset Verbeteringen
- **GEWIJZIGD**: Netsh nu primaire firewall reset methode (bewezen betrouwbaar)
- **AANGEPAST**: PowerShell cmdlet Restore-NetFirewallDefault nu fallback
- **TOEGEVOEGD**: BFE en MpsSvc service checks en auto-start
- **TOEGEVOEGD**: Return $true/$false voor success/failure tracking
- **VERBETERD**: Firewall reset outcome correct doorgegeven aan status display
- **TOEGEVOEGD**: Exitcode controle via $LASTEXITCODE i.p.v. Start-Process
- **VERBETERD**: Output redirection via *> $null (betrouwbaarder)
- **TOEGEVOEGD**: Firewall outcome zichtbaar in completion status (+/-)

### 🖱️ Snelkoppeling Verbeteringen  
- **TOEGEVOEGD**: Adaptieve snelkoppeling o.b.v. EnableStartupTask configuratie
- **TOEGEVOEGD**: Met scheduled task: start via schtasks.exe (elevated, geen UAC)
- **TOEGEVOEGD**: Zonder scheduled task: self-elevate via PowerShell Start-Process -Verb RunAs
- **VERBETERD**: Snelkoppeling werkt nu in beide scenario's (taak enabled/disabled)
- **TOEGEVOEGD**: Return status voor snelkoppeling (created/updated/removed/absent/error)
- **VERBETERD**: Shortcut updates (overschrijft bestaande)
- **HERNOEMT**: `Manage-ReturnShortcut` → `Set-DesktopShortcut` (approved verb)

### 📊 Status Display Voorbeelden

**Met alle features enabled:**
```
===================================================
  OPSCHONING VOLTOOID - APPARAAT KLAAR VOOR UITLEEN
===================================================
Tijdstip: 2025-10-23 20:15:42
Versie: 1.5.0
Uitvoeringstijd: 4.8 seconden

+ Browsers gestopt en data verwijderd (chrome, firefox, msedge)
+ Wi-Fi profielen gefilterd (whitelist actief)
+ Tijdelijke bestanden opgeschoond
+ Firewall gereset naar standaardinstellingen

Voorzieningen:
+ Geplande taak bijgewerkt: Opstart-Script
+ Snelkoppeling op bureaublad bijgewerkt

STATUS: SUCCES - Apparaat is schoon en klaar
===================================================
```

**Met firewall disabled:**
```
+ Browsers gestopt en data verwijderd (chrome, firefox, msedge)
+ Wi-Fi profielen gefilterd (whitelist actief)
+ Tijdelijke bestanden opgeschoond
- Firewall reset (uitgeschakeld in configuratie)
```

### 🐛 Bugfixes
- **OPGELOST**: Scheduled task fout "AllowStartOnDemand parameter not found" op oudere PS versies
- **OPGELOST**: Netsh exitcode -1 door onjuiste Start-Process + NUL file redirection
- **OPGELOST**: Firewall status altijd "voltooid" ook bij falen (return value ontbrak)
- **OPGELOST**: ForceUpdate blijft enabled in hidden copy → oneindige update loop
- **OPGELOST**: Snelkoppeling werkt niet zonder elevated context (UAC/task scenario's)

### 🔐 AVG Compliance & Privacy
- **VERWIJDERD**: Logging van gebruikersnamen in `Stop-Browsers` functie
- **VERWIJDERD**: Logging van Wi-Fi netwerknamen in logs en Event Log
- **TOEGEVOEGD**: `-SkipEventLog` parameter voor gevoelige berichten (Wi-Fi profielen)
- **TOEGEVOEGD**: `$LogRetentionDays` configuratie (standaard 30 dagen)
- **TOEGEVOEGD**: Automatische cleanup van logs én backups na $LogRetentionDays
- **TOEGEVOEGD**: Clear-OldBackups functie met LogRetentionDays cutoff
- **VERBETERD**: Backup-Log verwijdert nu ook oude gearchiveerde logs (script_*.log)
- **VERBETERD**: Wi-Fi logging toont alleen aantallen, geen netwerknamen in Event Log
- **TOEGEVOEGD**: AVG-compliance notitie in script header
- **TOEGEVOEGD**: AVG-COMPLIANCE.md met volledige privacy documentatie

### 📝 Code Kwaliteit & Best Practices
- **HERNOEMT**: `Manage-StartupTask` → `Set-StartupTask` (approved PowerShell verb)
- **HERNOEMT**: `Manage-ReturnShortcut` → `Set-DesktopShortcut` (approved PowerShell verb)
- **TOEGEVOEGD**: Return values voor Set-StartupTask en Set-DesktopShortcut
- **VERBETERD**: Error handling in Set-StartupTask en Set-DesktopShortcut (return 'error')
- **TOEGEVOEGD**: Try-catch om alle Event Log operaties (mag script niet crashen)
- **VERBETERD**: Invoke-WithRetry nu compatible met functies die return values hebben
- **TOEGEVOEGD**: $global: scope voor HiddenFolderPath, LogFile, VersionFile
- **TOEGEVOEGD**: Uitgebreide inline documentatie voor complexe functies

### ✅ Ontwerp Conformiteit
- **TOEGEVOEGD**: `$MaxExecutionMinutes` timeout controle (5 minuten)
- **TOEGEVOEGD**: `Show-CompletionStatus` functie voor duidelijke SUCCES/FAIL meldingen
- **TOEGEVOEGD**: `laatste_status.txt` bestand voor servicedesk
- **VERBETERD**: Visuele statusmeldingen met tijdsinformatie
- **TOEGEVOEGD**: Exit code 1 bij fouten voor monitoring

### Initial Setup Verbeteringen (initial-setup.bat)
- **TOEGEVOEGD**: 5-stappen verificatieproces met duidelijke feedback
- **TOEGEVOEGD**: PowerShell versie controle (min. 5.1)
- **TOEGEVOEGD**: Bestandsgrootte validatie (detecteert corrupte scripts)
- **TOEGEVOEGD**: Schrijfrechten test voor doelmap
- **TOEGEVOEGD**: Optie om logmap direct te openen na installatie
- **VERBETERD**: Uitgebreide error messages met troubleshooting tips
- **VERBETERD**: Exit code propagatie voor automation/monitoring
- **VERBETERD**: Visuele voortgangsindicatoren en stap-nummering

### Documentatie
- **BIJGEWERKT**: README.md met AVG-sectie en ontwerpverantwoording
- **BIJGEWERKT**: Script header met AVG-compliance notities
- **VERWIJDERD**: Alle verwijzingen naar fictieve klant (MBO College Rijnstad)
- **TOEGEVOEGD**: Volledige acceptatiecriteria verificatie
- **TOEGEVOEGD**: Privacy-by-design principes in code comments
- **TOEGEVOEGD**: CHANGELOG.md voor versiehistorie

###  Logging Wijzigingen

**v1.4.1 (oud - bevat PII):**
```powershell
Write-Log "Gestopt: chrome"
Write-Log "Behouden profiel: Thuis_WiFi"
Write-Log "Verwijder profiel: KPN_Hotspot"
```

**v1.5.0 (nieuw - AVG-conform):**
```powershell
Write-Log "Browser gestopt: chrome (3 processen)"
Write-Log "Wi-Fi opschoning: 5 verwijderd, 1 behouden"
Write-Log "Profiel verwijderd" -SkipEventLog
Write-Log "Profiel behouden (whitelist)" -SkipEventLog
```

### Initial Setup Batch Verbeteringen
- **TOEGEVOEGD**: Dynamic config import via -PrintConfig parameter
- **TOEGEVOEGD**: Configuratie preview met J/N confirmatie voor gebruiker
- **TOEGEVOEGD**: Fallback waarden indien config niet gelezen kan worden
- **VERBETERD**: ExecutionPolicy Bypass i.p.v. RemoteSigned (betrouwbaarder)
- **TOEGEVOEGD**: Detectie en weergave van alle configuratie-opties
- **TOEGEVOEGD**: Dynamische logpath weergave o.b.v. HiddenFolderName
- **VERBETERD**: Duidelijke scheiding tussen detectie en installatie fase
- **TOEGEVOEGD**: Opmaak met scheidingslijnen en secties

---

## [1.4.1] - 2025-10-03

### Toegevoegd
- Intelligente versiecontrole en update-mechanisme
- Backup systeem voor script-updates
- `$ForceUpdate` configuratie optie
- `$MaxRetries` configuratie voor retry-logica

### Verbeterd
- Foutafhandeling met `Invoke-WithRetry` functie
- Event Log integratie
- Automatische cleanup van oude backups (30 dagen)

### Notitie
⚠️ Deze versie bevat PII in logs en is NIET AVG-conform. Upgrade naar 1.5.0 vereist.

---

## [1.4.0] - 2025-09-15

### Toegevoegd
- `$EnableShortcut` configuratie voor bureaubladsnelkoppeling
- `$EnableStartupTask` configuratie voor opstarttaak
- `$EnableFirewallReset` configuratie
- Automatische cleanup bij uitschakelen features

### Verbeterd
- Smart configuratie: features auto-verwijderen bij disable
- Manage-StartupTask functie met aan/uit logica
- Manage-ReturnShortcut functie

---

## [1.3.0] - 2025-08-20

### Toegevoegd
- Chrome browser data opschoning
- Firefox profiel opschoning verbeterd
- Edge data verwijdering

### Verbeterd
- Browser lijst configureerbaar via `$BrowserList`
- Betere error handling per browser type

---

## [1.2.0] - 2025-08-15

### Toegevoegd
- Initiële versie met basis functionaliteit
- Wi-Fi profiel filtering met whitelist
- Windows Event Log integratie
- Geplande taak registratie
- Log rotatie mechanisme

---

## Upgrade Instructies

### Van 1.4.x naar 1.5.0 (AANBEVOLEN - AVG)

**Stap 1**: Zet `$ForceUpdate = $true` in script  
**Stap 2**: Voer script eenmalig handmatig uit  
**Stap 3**: Verifieer met AVG-checklist (zie AVG-COMPLIANCE.md §9.1)  
**Stap 4**: Controleer `laatste_status.txt` voor SUCCES melding  

**Automatische migratie**:
- Oude logs blijven bestaan maar worden binnen 30 dagen verwijderd
- Nieuwe logs bevatten geen PII meer
- Backups van oude script (v1.4.x) worden automatisch gemaakt

**Privacy Impact**: 
✅ Bestaande logs met PII worden automatisch verwijderd na 30 dagen  
✅ Nieuwe logs zijn direct AVG-conform  
⚠️ Overweeg handmatige cleanup van oude logs indien direct compliance vereist

---

## Breaking Changes

### v1.5.0
- **Logging output gewijzigd**: Scripts die logs parsen moeten worden aangepast
- **Event Log berichten anders**: Monitoring tools kunnen impact ondervinden
- **Nieuwe bestanden**: `laatste_status.txt` wordt aangemaakt

---

## Ontwerpconformiteit Matrix

| Eis | v1.4.1 | v1.5.0 |
|-----|--------|--------|
| AVG-compliance | ❌ | ✅ |
| 30 dagen retentie | ⚠️ Gedeeltelijk | ✅ |
| SUCCES/FAIL status | ❌ | ✅ |
| Max 5 min timeout | ❌ | ✅ |
| Geen PII in logs | ❌ | ✅ |
| Audit trails | ✅ | ✅ |
| Versiecontrole | ✅ | ✅ |
| Rollback mogelijk | ✅ | ✅ |

---

**Laatste update**: 23 oktober 2025  
**Maintainer**: Ruben Draaisma  
**Licentie**: Zie LICENSE bestand
