# AVG Compliance Documentatie
## Leenlaptop Opschoningsscript - Privacy & Gegevensbescherming

**Document versie**: 1.1  
**Datum**: 3 november 2025  
**Script versie**: 1.6.0  
**Verantwoordelijke**: ICT-beheerder

---

## 1. Inleiding

Dit document beschrijft hoe het leenlaptop opschoningsscript voldoet aan de Algemene Verordening Gegevensbescherming (AVG/GDPR). Het script is ontworpen volgens het **privacy-by-design** principe en minimaliseert de verwerking van persoonsgegevens.

---

## 2. Wettelijke Grondslag

### Artikel 6 AVG - Rechtmatigheid van verwerking
De verwerking is rechtmatig op basis van:
- **Art. 6 lid 1 sub f**: Gerechtvaardigd belang voor ICT-beveiliging en systeembeheer
- **Art. 6 lid 1 sub c**: Wettelijke verplichting (indien van toepassing bij overheidsinstellingen)

### Doel van de verwerking
- Waarborgen van IT-beveiliging
- Beschermen van privacy van volgende gebruikers
- Operationele continuïteit van leenlaptop-dienst
- Audit trails voor troubleshooting

---

## 3. Gegevensminimalisatie (Art. 5 lid 1 sub c AVG)

### 3.1 Wat wordt NIET gelogd (design keuze)
Het script logt **expliciet GEEN** persoonsgegevens zoals:
- ❌ Gebruikersnamen
- ❌ Wi-Fi netwerknamen (alleen aantallen)
- ❌ Bestandsnamen met persoonlijke informatie
- ❌ IP-adressen
- ❌ Browser geschiedenis of URLs
- ❌ Account informatie

### 3.2 Wat wordt WEL gelogd (minimaal noodzakelijk)
Het script logt alleen operationele informatie:
- ✅ Tijdstempel van operaties
- ✅ Soort operatie (bijv. "Browser gestopt")
- ✅ Aantallen (bijv. "3 processen gestopt")
- ✅ Foutcodes en technische statusmeldingen
- ✅ Script versie
- ✅ SUCCES/FAIL status

### 3.3 Code voorbeelden

**FOUT (oude versie - bevat PII):**
```powershell
# ❌ NIET AVG-conform
Write-Log "Gebruiker $env:USERNAME heeft browser chrome gesloten"
Write-Log "Wi-Fi profiel 'Thuis_Netwerk' verwijderd"
```

**CORRECT (huidige versie - geen PII):**
```powershell
# ✅ AVG-conform
Write-Log "Browser gestopt: chrome (3 processen)"
Write-Log "Wi-Fi opschoning: 5 verwijderd, 1 behouden"
```

---

## 4. Opslagbeperking (Art. 5 lid 1 sub e AVG)

### 4.1 Retentiebeleid

| Data Type | Retentieperiode | Rechtsgrond |
|-----------|-----------------|-------------|
| **Operationele logs** | 30 dagen | Troubleshooting, beveiliging |
| **Gearchiveerde logs** | 30 dagen | Audit trail |
| **Script backups** | 30 dagen | Herstel na fouten |
| **Status bestanden** | Tot volgende run | Operationele noodzaak |

### 4.2 Automatische verwijdering
Het script bevat **automatische cleanup-mechanismen**:

```powershell
# Automatische verwijdering van oude logs (dagelijks uitgevoerd)
function Backup-Log {
    $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)  # 30 dagen
    Get-ChildItem -Filter 'script_*.log' |
        Where-Object { $_.CreationTime -lt $cutoffDate } |
        Remove-Item -Force
}
```

**Verificatie**: Controleer `$LogRetentionDays` variabele in script (standaard: 30)

---

## 5. Integriteit en Vertrouwelijkheid (Art. 32 AVG)

### 5.1 Toegangsbeveiliging

| Beveiligingsmaatregel | Implementatie |
|----------------------|---------------|
| **Bestandslocatie** | `%LOCALAPPDATA%\HiddenScripts` (verborgen, per gebruiker) |
| **NTFS-rechten** | Alleen lokale gebruiker + ICT-admins |
| **Verborgen attribuut** | Map gemarkeerd als "Hidden" |
| **Schrijfrechten** | Alleen script zelf en admins |

### 5.2 Event Log Filtering
```powershell
# Privacy-filter: gevoelige berichten niet naar Event Log
Write-Log "Wi-Fi profiel verwijderd" -SkipEventLog  # Lokaal wel, Event Log niet
```

Rationale: Windows Event Log kan toegankelijk zijn voor meer gebruikers dan lokale logs.

### 5.3 Geen externe communicatie
Het script:
- ❌ Stuurt GEEN data naar externe servers
- ❌ Gebruikt GEEN netwerk verbindingen voor logging
- ❌ Deelt GEEN informatie met derden
- ✅ Werkt volledig lokaal op het apparaat

---

## 6. Rechten van Betrokkenen (Art. 15-22 AVG)

### 6.1 Transparantie (Art. 13-14)
- ✅ Script-doel wordt gecommuniceerd via README en documentatie
- ✅ Gebruikers worden geïnformeerd bij uitgifte leenlaptop
- ✅ Logbestanden zijn leesbaar (plain text, geen encryptie)

### 6.2 Inzagerecht (Art. 15)
Omdat het script **geen persoonsgegevens logt**, is er feitelijk niets in te zien.
Bij vragen kunnen gebruikers logs opvragen bij ICT, maar deze bevatten geen PII.

### 6.3 Recht op verwijdering (Art. 17)
- ✅ Automatisch na 30 dagen
- ✅ Handmatig door ICT op verzoek mogelijk
- ✅ Geen backups buiten retentieperiode

---

## 7. Verwerkersverantwoordelijkheden

### 7.1 ICT-afdeling taken
1. **Toegangsbeheer**: Regelmatig controleren wie toegang heeft tot log-locaties
2. **Monitoring**: Periodiek controleren of retentie correct werkt
3. **Updates**: Script up-to-date houden met security patches
4. **Training**: Gebruikers instrueren over privacy-aspecten

### 7.2 Audit-vragen bij inspectie
Bij AVG-audit kunnen volgende vragen worden gesteld:

**Q: Welke persoonsgegevens worden verwerkt?**  
A: Geen directe persoonsgegevens. Alleen operationele metadata (tijden, aantallen).

**Q: Hoe lang worden logs bewaard?**  
A: Maximaal 30 dagen, daarna automatisch verwijderd.

**Q: Wie heeft toegang tot logs?**  
A: Alleen ICT-beheerders met beheersrechten op betreffend apparaat.

**Q: Worden logs gedeeld met derden?**  
A: Nee, volledig lokaal opgeslagen, geen externe toegang.

**Q: Hoe wordt verwijdering gegarandeerd?**  
A: Automatisch via script-logica, dagelijks gecontroleerd tijdens uitvoering.

---

## 8. Risicoanalyse (DPIA Light)

### 8.1 Privacy Risico's

| Risico | Kans | Impact | Mitigatie |
|--------|------|--------|-----------|
| Logs bevatten PII | Laag | Hoog | Code review, unit tests, `-SkipEventLog` flag |
| Onbevoegde toegang logs | Laag | Gemiddeld | NTFS-rechten, verborgen map |
| Logs te lang bewaard | Zeer laag | Laag | Automatische cleanup + monitoring |
| Logs gekopieerd voor backup | Laag | Gemiddeld | Alleen ICT toegang, geen automatische backups |

### 8.2 Restrisico
**ACCEPTABEL** - Operationele logs zonder PII vormen minimaal privacy-risico.

---

## 9. Documentatie & Verificatie

### 9.1 Verificatie Checklist
Gebruik deze checklist om AVG-compliance te controleren:

```powershell
# 1. Controleer configuratie
$config = Get-Content "opstart-script.ps1" -Raw
$config -match '\$LogRetentionDays\s*=\s*30'  # Moet $true zijn

# 2. Controleer geen oude logs
$logFolder = "$env:LOCALAPPDATA\HiddenScripts"
Get-ChildItem $logFolder -Filter "script_*.log" | 
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-31) }
# Moet leeg zijn

# 3. Controleer laatste log op PII
$logContent = Get-Content "$logFolder\script.log" -Tail 50
# Moet GEEN gebruikersnamen, netwerknamen, emails bevatten

# 4. Test Event Log filtering
Get-EventLog -LogName Application -Source "OpstartScript" -Newest 10
# Controleer of gevoelige berichten -SkipEventLog flag gebruiken
```

### 9.2 Periodieke Review
- **Frequentie**: Elk kwartaal
- **Verantwoordelijke**: ICT Security Officer
- **Onderdelen**: Code review, log analyse, toegangscontrole

---

## 10. Wijzigingshistorie

| Versie | Datum | Wijziging | AVG Impact |
|--------|-------|-----------|------------|
| 1.4.1 | 2025-10-03 | Pre-AVG versie | Bevatte PII in logs (niet compliant) |
| 1.5.0 (Doc 1.0) | 2025-10-23 | Initiële AVG-compliance implementatie | Volledig herziening voor privacy |
| 1.6.0 (Doc 1.1) | 2025-11-03 | Volledig configureerbare opschoning + media-mappen + desktop detectie | Geen - blijft AVG-compliant |

### Document Versie 1.1 (Script v1.6.0) - AVG Analyse
**Nieuwe functionaliteit**: 
1. Desktop snelkoppeling detectie bij admin-sessies
2. Media-mappen opschoning (Afbeeldingen, Video's, Muziek)
3. Volledig configureerbare cleanup-opties
4. Verbeterde Wi-Fi status rapportage

**Privacy Impact Assessment per feature**:

**1. Desktop Detectie (Get-ActualUserDesktop)**
```powershell
# ❌ VERMEDEN: Username logging
# Get-ActualUserDesktop detecteert gebruiker maar logt geen naam

# ✅ GEÏMPLEMENTEERD: Alleen methode logging
Write-Log "Desktop bepaald via actieve console sessie" -SkipEventLog
# Geen username, gebruik -SkipEventLog voor extra privacy
```
- Detecteert gebruiker via query user/WMI maar logt **GEEN** username
- Gebruikt `-SkipEventLog` flag voor extra privacy
- Fallback naar Public Desktop (geen gebruikersspecifieke data)

**2. Media-mappen Opschoning (Pictures/Videos/Music)**
```powershell
# ✅ AVG-CONFORM: Alleen aantallen, geen bestandsnamen
Write-Log "Afbeeldingen-map geleegd (45 items verwijderd)"
# Geen bestandsnamen of gebruikersspecifieke informatie
```
- Logt alleen **aantallen**, geen bestandsnamen of paden
- WAARSCHUWING melding in log (bevat geen PII)
- Standaard **uitgeschakeld** (opt-in voor privacy)

**3. Verbeterde Status Rapportage**
```powershell
# ✅ AVG-CONFORM: Alleen statistieken
Write-Log "Wi-Fi opschoning: 3 verwijderd, 1 behouden"
# Geen netwerknamen, alleen aantallen
```
- Wi-Fi rapportage zonder netwerknamen (alleen counts)
- Browser lijst zonder gebruikersprofielen
- Alle statistieken geaggregeerd zonder PII

**Conclusie**: Geen AVG-impact. Script blijft volledig compliant.
- Alle nieuwe functies respecteren privacy-by-design principe
- Geen PII-logging toegevoegd
- `-SkipEventLog` gebruikt waar relevant
- Media-opschoning standaard uitgeschakeld (veilig)

---

## 11. Contactinformatie

**Privacy vragen**: ICT-beheerder  
**Functionaris Gegevensbescherming**: [Indien van toepassing]  
**Script auteur**: Ruben Draaisma  
**Laatste review**: 3 november 2025

---

## Appendix A: Code Snippets ter Referentie

### A.1 Logging zonder PII
```powershell
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO',
        [switch]$SkipEventLog  # Privacy flag
    )
    
    # Lokaal loggen (meer detail toegestaan)
    Add-Content -Path $LogFile -Value "$timestamp [$Level] $Message"
    
    # Event Log (alleen niet-PII)
    if (-not $SkipEventLog) {
        Write-EventLog ... -Message $Message
    }
}
```

### A.2 Automatische Retentie
```powershell
function Backup-Log {
    # Rotatie bij grootte-limiet
    if ((Get-Item $LogFile).Length / 1MB -ge $MaxLogSizeMB) {
        Rename-Item -Path $LogFile -NewName "script_$(Get-Date -f 'yyyyMMdd_HHmmss').log"
    }
    
    # AVG: Verwijder oude logs
    $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
    Get-ChildItem -Filter 'script_*.log' |
        Where-Object { $_.CreationTime -lt $cutoffDate } |
        Remove-Item -Force
}
```

---

**EINDE DOCUMENT**

*Dit document is onderdeel van het technisch ontwerp voor het Leenlaptop Opschoningsproces en beschrijft de AVG-compliance maatregelen.*
