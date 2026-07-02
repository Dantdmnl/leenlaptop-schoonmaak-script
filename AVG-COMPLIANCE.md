# AVG-compliance

## Leenlaptop Schoonmaak Script

**Documentversie:** 1.4
**Datum:** 2 juli 2026
**Scriptversie:** 1.6.3
**Verantwoordelijke:** ICT-beheerder

## 1. Doel en scope

Dit document beschrijft de privacymaatregelen in het leenlaptop-schoonmaakscript. Het script wordt lokaal uitgevoerd op Windows-apparaten en is bedoeld om leenlaptops na gebruik opnieuw beschikbaar te maken zonder persoonsgegevens van vorige gebruikers achter te laten.

De maatregelen in dit document richten zich op:

- dataminimalisatie;
- beperkte logretentie;
- lokale opslag;
- beperkte toegang tot logs;
- controleerbare uitvoering voor servicedesk en ICT.

## 2. Rechtsgrond en doelbinding

De verwerking is gebaseerd op het gerechtvaardigd belang van ICT-beheer en informatiebeveiliging. In sommige organisaties kan daarnaast een wettelijke of beleidsmatige verplichting gelden voor veilig apparaatbeheer.

Doelen:

- beschermen van volgende gebruikers tegen achtergebleven data;
- beperken van lokale privacy- en beveiligingsrisico's;
- vastleggen of de opschoning technisch is gelukt;
- ondersteunen van troubleshooting door ICT.

Het script is niet bedoeld voor gebruikersmonitoring.

## 3. Gegevensminimalisatie

Het script logt geen inhoudelijke gebruikersdata. De log bevat alleen operationele gegevens.

Niet gelogd:

- gebruikersnamen;
- bestandsnamen;
- browsergeschiedenis of URL's;
- IP-adressen;
- Wi-Fi-netwerknamen in Windows Event Log;
- accountinformatie.

Wel gelogd:

- tijdstip;
- type actie;
- aantallen verwijderde items;
- foutmeldingen zonder persoonsgegevens;
- scriptversie;
- eindstatus.

Voorbeeld:

```powershell
Write-Log "Wi-Fi opschoning voltooid: 5 verwijderd, 1 behouden"
```

Gevoelige detailmeldingen worden niet naar Windows Event Log geschreven wanneer `-SkipEventLog` wordt gebruikt.

## 4. Opslag en retentie

| Gegeven | Locatie | Retentie |
|---------|---------|----------|
| Actuele log | `C:\ProgramData\LeenlaptopSchoonmaak\log.txt` | Tot rotatie |
| Gearchiveerde logs | `script_YYYYMMDD_HHMMSS.log` | 30 dagen standaard |
| Scriptbackups | `backup_YYYYMMDD_HHMMSS_*.ps1` | 30 dagen en maximaal 5 standaard |
| Laatste status | `laatste_status.txt` | Tot volgende run |

Retentie is configureerbaar via:

```powershell
[int] $LogRetentionDays = 30
[int] $MaxBackupCount   = 5
```

## 5. Toegang en beveiliging

De bestanden staan onder:

```text
C:\ProgramData\LeenlaptopSchoonmaak
```

De map wordt verborgen gemaakt. Toegang hoort beperkt te zijn tot lokale beheerders, systeembeheer en ICT-medewerkers die verantwoordelijk zijn voor apparaatbeheer. Controle van NTFS-rechten blijft een beheermaatregel buiten het script.

Het script communiceert niet met externe diensten voor logging of rapportage. Alle logs blijven lokaal op het apparaat.

## 6. Event Log

Het script schrijft operationele statusmeldingen naar het Windows Application Log met bron `LeenlaptopSchoonmaak`. Berichten die mogelijk herleidbare details kunnen bevatten, worden alleen lokaal gelogd en overgeslagen voor Event Log.

Voor controle:

```powershell
Get-EventLog -LogName Application -Source "LeenlaptopSchoonmaak" -Newest 10
```

## 7. Rechten van betrokkenen

Omdat het script geen persoonsgegevens in de operationele log hoort vast te leggen, is de hoeveelheid inzage- of verwijderbare data beperkt. Als een gebruiker vragen stelt, kan ICT de lokale logs controleren en toelichten welke technische acties zijn uitgevoerd.

Handmatige verwijdering van logs kan door ICT worden uitgevoerd wanneer beleid of een verzoek daartoe aanleiding geeft.

## 8. Risicoanalyse

| Risico | Kans | Impact | Maatregel |
|--------|------|--------|-----------|
| Log bevat persoonsgegevens | Laag | Hoog | Geen bestandsnamen/gebruikersnamen loggen, `-SkipEventLog` voor detailmeldingen |
| Onbevoegde toegang tot logs | Laag | Gemiddeld | Opslag onder `C:\ProgramData`, beheer via NTFS-rechten |
| Logs blijven te lang staan | Laag | Laag | Automatische retentie op logs en backups |
| Te agressieve folder-cleanup | Laag | Hoog | Documenten/media standaard uit, leeftijdsfilter, lege-mappenlogica |

Restrisico: acceptabel bij correcte configuratie en periodieke controle door ICT.

## 9. Controlepunten voor beheer

Periodieke controle:

```powershell
# Configuratie controleren
Select-String -Path "C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1" -Pattern "LogRetentionDays|MaxBackupCount"

# Oude logs controleren
Get-ChildItem "C:\ProgramData\LeenlaptopSchoonmaak" -Filter "script_*.log" |
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-31) }

# Recente status controleren
Get-Content "C:\ProgramData\LeenlaptopSchoonmaak\laatste_status.txt"
```

Aanbevolen frequentie: elk kwartaal of na elke inhoudelijke release.

## 10. Wijzigingshistorie

| Scriptversie | Datum | Relevante wijziging | Privacy-impact |
|--------------|-------|---------------------|----------------|
| 1.5.0 | 2025-10-23 | Eerste AVG-gerichte herziening | PII-logging verwijderd |
| 1.6.0 | 2025-11-03 | Verplaatsing naar `C:\ProgramData`, configureerbare cleanup | Geen negatieve impact |
| 1.6.1 | 2025-12-07 | Verbeterde browsercleanup | Positief, meer lokale accountdata verwijderd |
| 1.6.2 | 2026-01-14 | Backuplimiet, hashcontrole, configuratievalidatie | Positief, betere integriteit en opslagbeperking |
| 1.6.3 | 2026-07-02 | Veiligere leeftijdsfiltering en documentatiecorrecties | Positief, lager risico op onbedoeld dataverlies |

## 11. Contact

Privacyvragen: ICT-beheerder
Functionaris Gegevensbescherming: invullen indien van toepassing
Scriptbeheer: Ruben Draaisma
