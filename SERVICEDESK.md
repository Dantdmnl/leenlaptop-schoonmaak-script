# Servicedesk Handleiding - Leenlaptop Schoonmaak Script

> **Versie:** 1.6.1  
> **Voor:** Servicedesk medewerkers en ICT-beheerders  
> **Laatst bijgewerkt:** 7 december 2025

---

## 📋 Wat doet dit script?

Dit script **schoont automatisch een leenlaptop op** bij elke opstart. Het verwijdert:
- Browserdata (cookies, cache, geschiedenis)
- WiFi-profielen (oude netwerken)
- Tijdelijke bestanden
- Oude bestanden in Downloads/Documenten
- Media bestanden (Afbeeldingen, Video's, Muziek)
- Windows Firewall reset naar standaardinstellingen

**Belangrijk:** Het script werkt op de mappen van **de ingelogde gebruiker**, niet van de Administrator!

---

## 🚀 Eerste Installatie

### Stap 1: Download en pak uit
1. Download de ZIP van GitHub
2. Pak uit naar een tijdelijke map
3. Open de map in Verkenner

### Stap 2: Draai initial-setup.bat
1. **Rechtermuisknop** op `initial-setup.bat`
2. Kies **"Als administrator uitvoeren"**
3. Controleer de configuratie op het scherm
4. Typ `j` en druk op Enter

### Stap 3: Controleer installatie
Na installatie zie je:
- ✅ Snelkoppeling op het bureaublad: **"Leenlaptop Opschonen"**
- ✅ Geplande taak in Taakplanner: **"LeenlaptopSchoonmaak"**
- ✅ Script in: `C:\ProgramData\LeenlaptopSchoonmaak\opstart-script.ps1`
- ✅ Log in: `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`

---

## 🎯 Dagelijks Gebruik

### Automatisch bij opstart
- Script draait **automatisch** wanneer gebruiker inlogt
- Geen actie nodig van gebruiker of servicedesk
- Log wordt opgeslagen in: `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`

### Handmatig opstarten
Gebruiker kan ook handmatig starten via:
1. **Dubbelklik** op bureaublad-snelkoppeling **"Leenlaptop Opschonen"**
2. Of: Open **Taakplanner** (`taskschd.msc`) → Zoek **"LeenlaptopSchoonmaak"** → Rechtsklik → **Uitvoeren**

**Let op:** Handmatig starten vraagt om UAC-bevestiging (administrator prompt)

---

## 🔍 Problemen Oplossen

### Probleem: Script draait niet bij opstart
**Controleer:**
1. Is de geplande taak actief?
   - Open **Taakplanner** (`taskschd.msc`)
   - Zoek naar **"LeenlaptopSchoonmaak"**
   - Status moet **"Gereed"** zijn
   - Laatste uitvoercode moet **"0x0"** zijn

2. Kijk in de logfile:
   ```
   C:\ProgramData\LeenlaptopSchoonmaak\log.txt
   ```
   - Zie je recente timestamps?
   - Staan er foutmeldingen?

**Oplossing:** Herinstalleer via `initial-setup.bat` als administrator

---

### Probleem: Script vraagt steeds om wachtwoord
**Oorzaak:** Scheduled task is niet correct geregistreerd

**Oplossing:**
1. Open PowerShell **als administrator**
2. Navigeer naar script-map:
   ```powershell
   cd C:\ProgramData\LeenlaptopSchoonmaak
   ```
3. Herregistreer de taak:
   ```powershell
   .\opstart-script.ps1
   ```

---

### Probleem: Gebruiker klaagt dat persoonlijke bestanden weg zijn
**Diagnose:**
1. Vraag **welke bestanden** en **welke map**
2. Kijk welke cleanup functies actief zijn in het script

**Belangrijke configuratie-instellingen:**
| Instelling | Standaard | Effect |
|------------|-----------|--------|
| `$EnableBrowserCleanup` | `$true` | Browser data verwijderen |
| `$EnableWiFiCleanup` | `$true` | WiFi-profielen verwijderen |
| `$EnableTempCleanup` | `$true` | Temp-bestanden verwijderen |
| `$EnableDownloadsCleanup` | `$true` | Downloads > 7 dagen oud |
| `$EnableFirewallReset` | `$true` | Firewall naar standaard |
| `$EnableDocumentsCleanup` | `$false` | Documenten > 30 dagen oud |
| `$EnablePicturesCleanup` | `$false` | Afbeeldingen > 30 dagen oud |
| `$EnableVideosCleanup` | `$false` | Video's > 30 dagen oud |
| `$EnableMusicCleanup` | `$false` | Muziek > 30 dagen oud |

**Standaard ACTIEF:**
- ✅ Browser cleanup (Chrome, Edge, Firefox)
- ✅ WiFi cleanup (alle profielen)
- ✅ Temp cleanup (%TEMP%)
- ✅ Downloads cleanup (>7 dagen)
- ✅ Firewall reset

**Standaard UITGESCHAKELD:**
- ❌ Documenten cleanup (te risicovol)
- ❌ Media cleanup (Afbeeldingen/Video's/Muziek)

**Acties:**
- Leg uit dat oudere bestanden (>7 of >30 dagen) verwijderd worden
- Leenlaptops zijn **tijdelijk**, gebruikers moeten werk opslaan op netwerk/cloud
- Check of configuratie niet per ongeluk is aangepast

---

### Probleem: Snelkoppeling staat op verkeerd bureaublad
**Symptoom:** Snelkoppeling verschijnt op Administrator-bureaublad ipv gebruiker

**Oorzaak:** Script werd geïnstalleerd terwijl ingelogd als admin via RDP/remote sessie

**Oplossing:**
1. Log lokaal in als de gebruiker (niet via remote desktop als admin)
2. Herinstalleer met `initial-setup.bat` als administrator
3. Of: Kopieer snelkoppeling handmatig naar `C:\Users\[gebruiker]\Desktop`

---

### Probleem: WiFi-profielen worden niet verwijderd
**Symptoom:** Status toont "Geen profielen gevonden" maar gebruiker heeft wel profielen

**Oorzaak:** Script draait zonder administrator-rechten

**Herkenning in log:**
```
[WAARSCHUWING] Script draait NIET als administrator. Sommige functies zijn beperkt:
  - WiFi-profielen verwijderen
  - Firewall resetten
  - Scheduled task registreren
```

**Oplossing:**
- Geplande taak moet draaien met "Highest privileges" (standaard zo ingesteld)
- Controleer in Taakplanner: Eigenschappen → tab "Algemeen" → vinkje "Met hoogste bevoegdheden uitvoeren"

---

## 📊 Logbestanden Lezen

### Log locatie
```
C:\ProgramData\LeenlaptopSchoonmaak\log.txt
```

### Voorbeeld log-entries
```
2025-12-07 09:15:23 | INFO | ==================================================
2025-12-07 09:15:23 | INFO | START Leenlaptop Schoonmaak Script v1.6.1
2025-12-07 09:15:23 | INFO | ==================================================
2025-11-03 09:15:24 | SUCCESS | Browsers gesloten: 2 processen
2025-11-03 09:15:25 | SUCCESS | Browserdata verwijderd voor Chrome
2025-11-03 09:15:26 | SUCCESS | WiFi-profielen opgeschoond (Removed: 3, Kept: 1)
2025-11-03 09:15:27 | SUCCESS | Temp-bestanden verwijderd: 145 bestanden
2025-11-03 09:15:28 | INFO | Downloads cleanup overgeslagen (uitgeschakeld)
2025-11-03 09:15:29 | SUCCESS | Firewall teruggezet naar standaardinstellingen
2025-11-03 09:15:30 | SUCCESS | Log geroteerd (oude entries verwijderd)
2025-11-03 09:15:31 | INFO | ==================================================
2025-11-03 09:15:31 | INFO | EINDE Script - Status: SUCCESS
2025-11-03 09:15:31 | INFO | ==================================================
```

### Status types begrijpen
| Status | Betekenis | Actie nodig? |
|--------|-----------|--------------|
| `INFO` | Informatie over voortgang | Nee |
| `SUCCESS` | Actie succesvol uitgevoerd | Nee |
| `WARNING` | Waarschuwing, maar script loopt door | Controleer context |
| `ERROR` | Fout opgetreden, functie overgeslagen | Ja, onderzoek oorzaak |

---

## ⚙️ Configuratie Aanpassen

### Waar staat de configuratie?
In het script zelf: `C:\ProgramData\LeenlaptopSchoonmaak\opstart-script.ps1`

**Regels 40-100** bevatten alle instellingen (na het `#region Configuratie` blok).

### ⚠️ BELANGRIJK: Syntax voor Array-waarden

Bij het aanpassen van WiFi-netwerken of browsers, **gebruik altijd quotes**:

**❌ FOUT (crasht script):**
```powershell
[string[]]$AllowedWiFi = @(kantoor-wifi)        # FOUT: geen quotes!
[string[]]$BrowserList = @(chrome, firefox)     # FOUT: geen quotes!
```

**✅ GOED:**
```powershell
[string[]]$AllowedWiFi = @('kantoor-wifi')           # 1 netwerk
[string[]]$AllowedWiFi = @('kantoor-wifi', 'gast')   # Meerdere netwerken
[string[]]$AllowedWiFi = @()                         # Lege array = alles verwijderen
[string[]]$BrowserList = @('chrome', 'firefox')      # Meerdere browsers
```

### Veelvoorkomende aanpassingen

#### 1. WiFi netwerken behouden (whitelist)
```powershell
# Alle WiFi netwerken verwijderen (standaard):
[string[]]$AllowedWiFi = @()

# Specifieke netwerken BEHOUDEN:
[string[]]$AllowedWiFi = @('kantoor-wifi', 'gast-netwerk')
```

#### 2. Downloads cleanup aanpassen
```powershell
$EnableDownloadsCleanup = $true      # Standaard: $true
$DownloadsMaxAgeDays = 14            # Standaard: 7 dagen
```

#### 3. Documenten cleanup inschakelen (VOORZICHTIG!)
```powershell
$EnableDocumentsCleanup = $true      # Standaard: $false
$DocumentsMaxAgeDays = 30            # Bestanden ouder dan 30 dagen
```

#### 4. Browser cleanup uitschakelen
```powershell
$EnableBrowserCleanup = $false       # Standaard: $true
```

#### 5. Log retentie aanpassen
```powershell
$LogRetentionDays = 60               # Standaard: 30 dagen
```

### Configuratie toepassen
1. Open `opstart-script.ps1` in **Kladblok** of **PowerShell ISE** (als administrator)
2. Pas waarde aan (let op `$true` / `$false` en **quotes bij strings**)
3. **Sla op**
4. Wijziging is direct actief bij volgende run

**Let op:** Gebruik `initial-setup.bat` NIET opnieuw, anders worden je aanpassingen overschreven!

---

## 🎓 Voorbeeldscenario's

### Scenario 1: Standaard Leenlaptop (aanbevolen)
**Situatie:** Normale leenlaptop voor tijdelijk gebruik

**Configuratie:** (al standaard ingesteld!)
```powershell
$EnableBrowserCleanup = $true        # Browser data wissen
$EnableWiFiCleanup = $true           # WiFi-profielen verwijderen
$EnableTempCleanup = $true           # Temp-bestanden wissen
$EnableDownloadsCleanup = $true      # Downloads opschonen (>7 dagen)
$DownloadsMaxAgeDays = 7
$EnableFirewallReset = $true         # Firewall resetten
$EnableDocumentsCleanup = $false     # Documenten NIET verwijderen
$EnablePicturesCleanup = $false      # Media NIET verwijderen
```

### Scenario 2: Evenement (kortstondig gebruik)
**Situatie:** Laptop voor evenement/beurs, gebruiker mag niks achterlaten

**Configuratie:**
```powershell
$EnableDownloadsCleanup = $true      # Aggressive cleanup
$DownloadsMaxAgeDays = 1             # Al na 1 dag verwijderen
$EnableDocumentsCleanup = $true      # Ook documenten
$DocumentsMaxAgeDays = 1
$EnablePicturesCleanup = $true       # En media
$PicturesMaxAgeDays = 1
$EnableVideosCleanup = $true
$VideosMaxAgeDays = 1
```

### Scenario 3: Thuiswerker (langdurig gebruik)
**Situatie:** Medewerker werkt tijdelijk thuis, mag bestanden bewaren

**Configuratie:**
```powershell
$EnableDownloadsCleanup = $true      # Wel opschonen
$DownloadsMaxAgeDays = 30            # Maar pas na 30 dagen
$EnableDocumentsCleanup = $false     # Documenten NIET verwijderen
$EnablePicturesCleanup = $false      # Media NIET verwijderen
$EnableFirewallReset = $false        # Firewall met rust laten
```

### Scenario 4: Presentatielaptop
**Situatie:** Laptop voor presentaties/demo's, geen persoonlijke data

**Configuratie:**
```powershell
$EnableBrowserCleanup = $true        # Browser cleanup
$EnableWiFiCleanup = $false          # WiFi bewaren (vaste locatie)
$EnableTempCleanup = $true           # Temp cleanup
$EnableDownloadsCleanup = $false     # Rest uitgeschakeld
$EnableFirewallReset = $false        # Firewall met rust
```

---

## 🔐 Privacy & AVG

### Welke data wordt gelogd?
- ✅ Tijdstempel van acties
- ✅ Aantal verwijderde bestanden/profielen
- ✅ Succes/fout status van acties
- ❌ **GEEN** gebruikersnamen
- ❌ **GEEN** bestandsnamen
- ❌ **GEEN** netwerknamen (SSID's)

### Hoe lang worden logs bewaard?
- **Standaard:** 30 dagen (instelbaar via `$MaxLogAgeDays`)
- Automatische rotatie bij elke run
- Alleen lokaal opgeslagen (niet naar netwerk/cloud)

### Wie heeft toegang tot logs?
- Alleen gebruikers met **administrator-rechten**
- Locatie: `C:\ProgramData` (systeemmap, niet toegankelijk voor normale gebruikers)

---

## � Migratie van v1.5.0 naar v1.6.0

### Wat verandert er?
- **Oude locatie:** `%LOCALAPPDATA%\HiddenScripts` (per gebruiker)
- **Nieuwe locatie:** `C:\ProgramData\LeenlaptopSchoonmaak` (systeem-breed)
- **Oude task naam:** `Opstart-Script`
- **Nieuwe task naam:** `LeenlaptopSchoonmaak`
- **Oude snelkoppeling:** `Terug naar start.lnk`
- **Nieuwe snelkoppeling:** `Leenlaptop Opschonen.lnk`

### Automatische migratie
Script detecteert v1.5.0 installatie automatisch en:
1. ✅ Kopieert alle bestanden naar nieuwe locatie
2. ✅ Verwijdert oude scheduled task (`Opstart-Script`)
3. ✅ Verwijdert oude snelkoppelingen
4. ✅ Registreert nieuwe scheduled task (`LeenlaptopSchoonmaak`)
5. ✅ Ruimt oude map op

**Actie servicedesk:** Geen! Draai gewoon `initial-setup.bat` opnieuw als administrator.

### Handmatige migratie (indien nodig)
Als automatische migratie faalt:

1. **Verwijder oude scheduled task:**
   ```powershell
   Unregister-ScheduledTask -TaskName "Opstart-Script" -Confirm:$false
   ```

2. **Verwijder oude snelkoppeling:**
   - Check bureaublad voor `Terug naar start.lnk` of `Laptop Opschonen.lnk`
   - Verwijder handmatig

3. **Herinstalleer:**
   - Draai `initial-setup.bat` als administrator
   - Nieuwe versie wordt geïnstalleerd

---

## �📞 Escalatie

### Wanneer escaleren naar ICT?
- Script blijft crashen (log vol met ERROR)
- Geplande taak start niet (ook niet handmatig)
- Gebruiker rapporteert verlies van belangrijke data
- Configuratie-aanpassing nodig die je niet begrijpt
- Migratie van v1.5.0 faalt herhaaldelijk

### Wat meegeven bij escalatie?
1. **Logbestand:** `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`
2. **Oude log (indien migratie):** `%LOCALAPPDATA%\HiddenScripts\script.log`
3. **Screenshot** van foutmelding (indien van toepassing)
4. **Omschrijving:** Wat deed de gebruiker? Wat ging fout?
5. **Laptop-info:** Computernaam, Windows versie
6. **Script versie:** Check `version.txt` in script-map

---

## 📚 Meer Informatie

- **Technische documentatie:** `README.md`
- **Wijzigingshistorie:** `CHANGELOG.md`
- **Privacy-compliance:** `AVG-COMPLIANCE.md`
- **Broncode:** `opstart-script.ps1`

---

## ✅ Checklist Nieuwe Laptop

Bij het klaarmaken van een nieuwe leenlaptop:

- [ ] Windows updates geïnstalleerd
- [ ] Antivirussoftware actief
- [ ] Lokale admin-account aangemaakt
- [ ] **Script geïnstalleerd via `initial-setup.bat`**
- [ ] **Geplande taak gecontroleerd in Taakplanner**
- [ ] **Snelkoppeling aanwezig op bureaublad**
- [ ] Test run uitgevoerd (handmatig via snelkoppeling)
- [ ] Log gecontroleerd: `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`
- [ ] Gebruiker geïnformeerd over automatische cleanup

---

**Vragen? Problemen?**  
Neem contact op met ICT-beheer of check de GitHub repository voor updates.
