# Changelog - Leenlaptop Opschoningsscript

Alle belangrijke wijzigingen aan dit project worden gedocumenteerd in dit bestand.

---

## [1.6.2] - 2026-01-14

### ✨ Code Kwaliteit & Optimalisatie
- **VERBETERD**: Eliminatie van 160+ regels duplicatie - 5 folder cleanup functies geconsolideerd naar 1 generieke `Clear-UserFolder`
- **TOEGEVOEGD**: `Clear-UserFolder` met parameters voor `FolderType`, `MaxAgeDays` en `-ShowWarning` switch
- **VERBETERD**: Hard-coded `C:\Users` vervangen door `$env:SystemDrive\Users` (werkt ook op niet-standaard installaties)
- **VERBETERD**: Hard-coded `C:\` vervangen door `$env:SystemDrive` in desktop detectie (compatibiliteit met andere drives)
- **TOEGEVOEGD**: Null-check in `Stop-Browsers` functie voor betere robuustheid
- **VERBETERD**: `Stop-Browsers` - Firefox krijgt nu 7 retries ipv 3 (langzame afsluiting handling)
- **VERBETERD**: `Stop-Browsers` - Verifiëert dat processen echt gestopt zijn (met status checks)
- **VERBETERD**: Browser stop feedback - logt poging nummer bij success

### 🔍 Configuratie Validatie
- **NIEUW**: `Test-Configuration` functie valideert alle parameters bij script start
- **TOEGEVOEGD**: Validatie numerieke waarden (> 0 checks voor MB, dagen, minuten)
- **TOEGEVOEGD**: Validatie array types en structuur
- **TOEGEVOEGD**: Uitgebreide browser validatie - toegestane browsers: msedge, chrome, firefox, brave, opera, vivaldi
- **TOEGEVOEGD**: WiFi array validatie - geen lege strings toegestaan
- **TOEGEVOEGD**: MaxBackupCount validatie (mag niet negatief zijn)

### 💾 Backup Management Verbetering
- **NIEUW**: `MaxBackupCount` configuratie (standaard: 5, 0 = onbeperkt)
- **TOEGEVOEGD**: SHA256 hash verificatie na script kopieren - integriteit controle
- **VERBETERD**: `Clear-OldBackups` refactored - twee onafhankelijke stappen:
  - Stap 1: Verwijder backups ouder dan retentieperiode (AVG compliance)
  - Stap 2: Enforce maximaal aantal backups (limiet enforcement)
- **GEREPAREERD**: Backup limiet werkte niet door early return - nu altijd geactiveerd
- **GEREPAREERD**: `.Count` bug in backup limiet - nu met array wrapper `@()`
- **VERBETERD**: Backup failure logging - generic message naar Event Log, details naar file log
- **VERBETERD**: Hash mismatch logging - geen paden in Event Log
- **TOEGEVOEGD**: Individuele logging per verwijderde backup (limiet enforcement)

### 🔧 Error Handling & Logging
- **VERBETERD**: `Clear-OldBackups` feedback voor beide opschoningsszenaario's
- **VERBETERD**: Betere foutmeldingen met aantal gefaalde items
- **TOEGEVOEGD**: Melding wanneer geen oude backups gevonden worden (retentie informatie)
- **VERBETERD**: Backup kopieerfout blokkeert update niet meer - logt warning en gaat door
- **VERBETERD**: Hash verification fout gelogd, maar blokkeert andere taken niet

### 🔐 AVG & Privacy Compliance
- **VERBETERD**: Edge profiel logging nu met `-SkipEventLog` (profielnamen alleen in file log)
- **VERBETERD**: Chrome profiel logging nu met `-SkipEventLog` (profielnamen alleen in file log)
- **BEHOUDEN**: Firefox profiel logging al correct met `-SkipEventLog` (was al AVG-compliant)
- **VERBETERD**: Backup exception logging opgesplitst - generic warning naar Event Log, details naar file log
- **VERBETERD**: Hash verificatie details naar file log via `-SkipEventLog`

### 🐛 Bugfixes
- **GEREPAREERD**: Batch script quote escaping issue - temp bestand voor config uitlezing (ASCII encoding)
- **GEREPAREERD**: UTF-8 BOM issue in batch config import - changed naar ASCII encoding
- **GEREPAREERD**: PowerShell 5.1 incompatibiliteit - ternary operator `?:` → `if/else`
- **GEREPAREERD**: Backup Measure-Object count bug in Clear-UserFolder - array assignment
- **GEREPAREERD**: Backup limiet enforcement logica - `.Count` met array wrapper

### 📝 Documentatie & Batch Script
- **BIJGEWERKT**: Versienummer naar 1.6.2 in alle bestanden
- **BIJGEWERKT**: Laatste wijzigingsdatum naar 2026-01-14
- **TOEGEVOEGD**: `PS_MaxBackupCount` fallback in batch script (standaard: 10)
- **TOEGEVOEGD**: "Max backups" in RETENTIE sectie van batch summary
- **VERBETERD**: Max backups display - "ONBEPERKT" wanneer waarde is 0

### 🎯 User Experience
- **NIEUW**: `Write-Progress` voortgangsbalk met 11 stappen voor real-time feedback
- **TOEGEVOEGD**: Progress indicatoren voor: Script installeren, Browsers, WiFi, Temp, Downloads, Documenten, Afbeeldingen, Video's, Muziek, Firewall, Voorzieningen
- **VERBETERD**: Gebruiker ziet nu exact welke stap wordt uitgevoerd tijdens opschoning
- **VERBETERD**: Progress bar wordt netjes afgesloten na voltooiing

### 🐛 Bugfixes
- **GEREPAREERD**: Variable scope error - `$displayName:` → `${displayName}:` in error messages
- **GEREPAREERD**: quser parsing bug - `>gebruiker` wordt nu correct geparsed naar `gebruiker`
- **GEREPAREERD**: "Illegal characters in path" error bij desktop detectie
- **VERBETERD**: Regex pattern voor quser output met optionele `>` karakter handling

### 🔧 Error Handling
- **VERBETERD**: `Clear-OldBackups` geeft nu feedback over succesvolle én gefaalde verwijderingen
- **VERBETERD**: Betere foutmeldingen met aantal gefaalde items
- **TOEGEVOEGD**: Melding wanneer geen oude backups gevonden worden (retentie informatie)

### 📝 Documentatie
- **BIJGEWERKT**: Versienummer overal consistent naar 1.6.2
- **BIJGEWERKT**: Laatste wijzigingsdatum naar 2026-01-11
- **VERBETERD**: Code comments voor nieuwe functies en validaties

---

## [1.6.1] - 2025-12-07

### 🔒 Browser Cleanup Beveiligingsverbetering
- **VERBETERD**: Browser cleanup verwijdert nu ook synced account data (Microsoft/Google/Firefox Accounts)
- **VERBETERD**: `Clear-EdgeData` - Hybrid strategie: volledig profiel verwijderen → fallback naar granulaire cleanup
- **VERBETERD**: `Clear-FirefoxData` - Hybrid strategie met Firefox Sync, credentials en account data verwijdering
- **VERBETERD**: `Clear-ChromeData` - Hybrid strategie met Google Sync en account credentials verwijdering
- **TOEGEVOEGD**: Verwijdering van `Login Data`, `Login Data For Account` (credentials)
- **TOEGEVOEGD**: Verwijdering van `Preferences`, `Secure Preferences` (account + sync instellingen)
- **TOEGEVOEGD**: Verwijdering van `Sync Data`, `Sync Extension Settings` (sync cache)
- **TOEGEVOEGD**: Firefox: `key4.db`, `logins.json`, `signedInUser.json` (passwords + account)
- **TOEGEVOEGD**: Firefox: `weave/`, `sync.log`, `synced-tabs.db` (Firefox Sync data)
- **VEILIG**: Bij locked files → fallback naar granulaire cleanup (robuuste werking)
- **AVG**: Profielnamen alleen in lokale log met `-SkipEventLog` flag

### 🐛 Bugfixes
- **GEREPAREERD**: PowerShell syntax errors in browser cleanup functies (escaped colons in string interpolation)
- **GECORRIGEERD**: `$EnableBackupCleanup` comment - was "niet geïmplementeerd", maar functie bestond wel
- **VERBETERD**: `Clear-OldBackups` functie retourneert nu aantal verwijderde items (consistent met andere Clear-* functies)
- **TOEGEVOEGD**: Statusrapportage voor `$EnableBackupCleanup` in eindstatus (was missing)
- **GEÜNIFORMEERD**: Video's-map apostrof gebruik (dubbele quotes voor betere leesbaarheid)

### 📝 Documentatie
- **GECORRIGEERD**: `$EnableBackupCleanup` comment - nu "Oude script-backups verwijderen (gebruikt LogRetentionDays)"
- **VERBETERD**: Duidelijkere foutmeldingen in `Clear-OldBackups` met try-catch per backup
- **TOEGEVOEGD**: Betere logging voor hybrid browser cleanup strategy

### 🔐 AVG & Privacy
- **VERBETERD**: Browser cleanup verwijdert nu ook credentials en sync-data (conform privacy-by-design)
- **BEHOUDEN**: Geen PII in Event Log voor profielnamen (alleen in lokale logs)

---

## [1.6.0] - 2025-11-03

### ⚠️ BREAKING CHANGES - Automatische Migratie
- **GEWIJZIGD**: Installatiemap verplaatst van `%LOCALAPPDATA%\HiddenScripts` naar `C:\ProgramData\LeenlaptopSchoonmaak`
- **GEWIJZIGD**: Scheduled task naam: `Opstart-Script` → `LeenlaptopSchoonmaak`
- **GEWIJZIGD**: Snelkoppeling naam: `Terug naar start.lnk` → `Leenlaptop Opschonen.lnk`
- **GEWIJZIGD**: Logbestand naam: `script.log` → `log.txt`
- **GEWIJZIGD**: Event Log source: `OpstartScript` → `LeenlaptopSchoonmaak`
- **AUTOMATISCH**: Script detecteert v1.5.0 en migreert automatisch alle bestanden
- **AUTOMATISCH**: Oude scheduled task en snelkoppelingen worden verwijderd
- **VEILIG**: Oude map wordt alleen verwijderd na succesvolle migratie

### 🎯 Volledig Configureerbare Opschoning
- **TOEGEVOEGD**: `$EnableBrowserCleanup` - Browser opschoning in/uitschakelen (standaard: AAN)
- **TOEGEVOEGD**: `$EnableWiFiCleanup` - Wi-Fi profiel opschoning in/uitschakelen (standaard: AAN)
- **TOEGEVOEGD**: `$EnableTempCleanup` - Tijdelijke bestanden opschoning in/uitschakelen (standaard: AAN)
- **TOEGEVOEGD**: `$EnableDownloadsCleanup` - Downloads-map opschoning in/uitschakelen (standaard: AAN)
- **TOEGEVOEGD**: `$DownloadsMaxAgeDays` - Alleen bestanden ouder dan X dagen (standaard: 7)
- **TOEGEVOEGD**: `$EnableDocumentsCleanup` - Documenten-map opschoning in/uitschakelen (standaard: UIT)
- **TOEGEVOEGD**: `$DocumentsMaxAgeDays` - Alleen bestanden ouder dan X dagen (standaard: 30)
- **TOEGEVOEGD**: `$EnablePicturesCleanup` - Afbeeldingen-map opschoning in/uitschakelen (standaard: UIT)
- **TOEGEVOEGD**: `$PicturesMaxAgeDays` - Alleen bestanden ouder dan X dagen (standaard: 30)
- **TOEGEVOEGD**: `$EnableVideosCleanup` - Video's-map opschoning in/uitschakelen (standaard: UIT)
- **TOEGEVOEGD**: `$VideosMaxAgeDays` - Alleen bestanden ouder dan X dagen (standaard: 30)
- **TOEGEVOEGD**: `$EnableMusicCleanup` - Muziek-map opschoning in/uitschakelen (standaard: UIT)
- **TOEGEVOEGD**: `$MusicMaxAgeDays` - Alleen bestanden ouder dan X dagen (standaard: 30)
- **TOEGEVOEGD**: `$EnableFirewallReset` - Firewall reset in/uitschakelen (standaard: AAN)
- **TOEGEVOEGD**: `$EnableBackupCleanup` - Oude backups opschoning in/uitschakelen (standaard: AAN)

### 📁 Slimme User-Map Opschoning met Leeftijdsfiltering
- **TOEGEVOEGD**: `Clear-PicturesFolder` functie - Opschonen Afbeeldingen-map met leeftijdsfilter
- **TOEGEVOEGD**: `Clear-VideosFolder` functie - Opschonen Video's-map met leeftijdsfilter
- **TOEGEVOEGD**: `Clear-MusicFolder` functie - Opschonen Muziek-map met leeftijdsfilter
- **VERBETERD**: `Clear-DownloadsFolder` gebruikt nu `$DownloadsMaxAgeDays` (standaard: 7 dagen)
- **VERBETERD**: `Clear-DocumentsFolder` gebruikt nu `$DocumentsMaxAgeDays` (standaard: 30 dagen)
- **VERBETERD**: Alle functies verwijderen alleen bestanden ouder dan X dagen (niet alles!)
- **VERBETERD**: Alle user-map functies geven itemCount terug voor statusrapportage
- **VERBETERD**: WAARSCHUWING in logs bij opschonen van media-mappen
- **VEILIG**: Alle media-mappen standaard uitgeschakeld (zoals Documenten)
- **GEDOCUMENTEERD**: Alle functies bevatten comments over gebruikerscontext (ingelogde user)

### 🖥️ Desktop Snelkoppeling Verbeteringen
- **TOEGEVOEGD**: `Get-ActualUserDesktop` functie - Intelligente desktop detectie
- **VERBETERD**: Snelkoppeling wordt nu op juiste gebruiker's desktop geplaatst bij admin-sessies
- **TOEGEVOEGD**: Meerdere detectiemethodes: query user, WMI, Public Desktop fallback
- **AVG-COMPLIANT**: Geen usernames in logs, alleen detectiemethode
- **OPGELOST**: Snelkoppeling verschijnt niet meer op admin desktop bij elevated sessies
- **FALLBACK**: Public Desktop als vangnet (zichtbaar voor alle gebruikers)

### 📊 Verbeterde Status Rapportage
- **VERBETERD**: Wi-Fi cleanup geeft nu duidelijk terug: geen profielen/actie uitgevoerd/overgeslagen
- **VERBETERD**: Browser cleanup toont welke browsers verwerkt zijn
- **VERBETERD**: Elk cleanup item toont aantal verwerkte items waar relevant
- **VERBETERD**: Betere onderscheid tussen "uitgeschakeld", "was leeg", en "geen items gevonden"
- **TOEGEVOEGD**: Alle cleanup functies returnen getallen voor accurate rapportage

### 🎨 Initial Setup Verbeteringen
- **VERBETERD**: Setup toont nu gestructureerd overzicht: VOORZIENINGEN / OPSCHONING / RETENTIE
- **TOEGEVOEGD**: Alle nieuwe configuratieopties zichtbaar in setup
- **VERBETERD**: WAARSCHUWING! label bij hoge-risico opties (Documenten, Media)
- **VERBETERD**: Duidelijkere bevestigingstekst: "Wilt u doorgaan met de installatie?"
- **TOEGEVOEGD**: Browser- en WiFi-lijst details in configuratie-overzicht

### 🔒 AVG & Privacy
- **AVG-COMPLIANT**: Geen gebruikersnamen in logs bij desktop detectie
- **AVG-COMPLIANT**: `-SkipEventLog` flag voor PII-gevoelige berichten
- **ONGEWIJZIGD**: Logretentie blijft 30 dagen (AVG-conform)
- **VERBETERD**: Alle nieuwe functies respecteren AVG-logging principes

### �️ Admin Rights Handling
- **TOEGEVOEGD**: `Test-IsAdmin` functie - Detecteert administrator privileges
- **VERBETERD**: Script waarschuwt bij starten zonder admin rechten
- **VERBETERD**: WiFi cleanup, Firewall reset, Scheduled task graceful degradation
- **VERBETERD**: Functies returnen 'no-admin' status voor duidelijke rapportage
- **GEBRUIKSVRIENDELIJK**: Script crasht niet meer zonder admin rechten

### 📖 Documentatie
- **TOEGEVOEGD**: `SERVICEDESK.md` - Praktische handleiding voor servicedesk medewerkers
- **TOEGEVOEGD**: Migratie-instructies in SERVICEDESK.md (v1.5.0 → v1.6.0)
- **TOEGEVOEGD**: 4 scenario voorbeelden met concrete configuraties
- **TOEGEVOEGD**: Troubleshooting sectie met veelvoorkomende problemen
- **TOEGEVOEGD**: Checklist voor nieuwe laptop setup
- **VERBETERD**: README.md met configuratie-scenario's
- **VERBETERD**: AVG-COMPLIANCE.md met v1.6.0 privacy impact
- **TOEGEVOEGD**: GEBRUIKERSCONTEXT sectie in script header

### � Technische Verbeteringen
- **GEMODERNISEERD**: `Get-WmiObject` vervangen door `Get-CimInstance` (Windows 11 25H2 compatible)
- **TOEKOMSTBESTENDIG**: WMIC command-line tool is verwijderd in Windows 11 25H2, script gebruikt moderne CIM cmdlets
- **TOEGEVOEGD**: Configuratie instructies in script header (array syntax, quotes vereist)
- **TOEGEVOEGD**: Inline voorbeelden voor `$AllowedWiFi` en `$BrowserList` configuratie

### �🐛 Bugfixes
- **OPGELOST**: Ongebruikte `$desktop` variabele verwijderd uit `Get-ActualUserDesktop`
- **OPGELOST**: WiFi melding zei altijd "opgeschoond" zelfs als er geen profielen waren
- **OPGELOST**: Browser cleanup draaide altijd, nu alleen als `$EnableBrowserCleanup = $true`
- **OPGELOST**: Downloads path gebruikte string replace hack, nu Shell.Application COM object
- **OPGELOST**: Temp/user-folder cleanup functies verwijderden alles, nu alleen oude bestanden
- **OPGELOST**: Lege `$BrowserList` gaf geen duidelijke melding
- **OPGELOST**: Array syntax zonder quotes crashte script (nu gedocumenteerd met voorbeelden)

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
