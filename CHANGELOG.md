# Changelog

Alle relevante wijzigingen aan het leenlaptop-schoonmaakscript worden in dit bestand vastgelegd.

## [1.7.0] - 2026-10-10

Stabiele release van de utility met afzonderlijke installatie-, controle- en opschoonacties.

### Gewijzigd sinds rc.1

- Doelaccount krijgt expliciete lees- en startrechten op de geplande taak; oude taakrechten worden bij herstel teruggezet.
- Padcontrole omvat bestaande bovenliggende mappen van nog niet aangemaakte locaties. Installatie weigert programmabestanden die mappen of links zijn.
- Voorvertoning vanuit een ander account dan de geconfigureerde doelgebruiker wordt geweigerd.
- Tests uitgebreid met nep-browserprofielen en native WLAN-geheugenlayout: 34 geisoleerde tests.
- Integratietest op de tijdelijke GitHub Windows-runner voor installatie, taakregistratie, ACL's, snelkoppeling, CLI, rapportage, updates en taaktriggers. Alle opschoonfuncties staan tijdens deze test uit.
- API-gedrag en browseropslaglocaties gecontroleerd aan de hand van primaire documentatie; bronnen en testgrenzen vastgelegd in `VALIDATION.md`.

Live browserafsluiting, Wi-Fi-verwijdering en firewallreset zijn niet uitgevoerd. Controle van de eigen beheeromgeving blijft nodig voordat de utility breed wordt ingezet.


## [1.7.0-rc.1] - 2026-10-10

Releasecandidate; echte installatie en opschoning vereisen nog acceptatie op een testapparaat.

### Gewijzigd

- Installatie, controle en opschoning zijn afzonderlijke acties; zonder argumenten wordt alleen gecontroleerd.
- Externe JSON-configuratie met typevalidatie en behoud van instellingen bij updates.
- Migratie leest letterlijke instellingen uit oude scripts zonder deze uit te voeren.
- Expliciet doelaccount op basis van SID; opschoning vanuit een ander account wordt geweigerd.
- Geplande taak gebruikt de interactieve sessie van het doelaccount. Automatische uitvoering bij aanmelden vereist expliciete configuratie.
- Volledige lokale browseropslag wordt gewist, inclusief meerdere en aangepaste profielen.
- Resultaten per stap, JSON-rapporten en exitcodes voor geslaagd, gedeeltelijk geslaagd en mislukt.
- `-WhatIf` zonder installatie-, log- of statuswijzigingen.
- SHA256-verificatie, pakketmanifest, installatiebackups en herstel van bestanden en taak bij mislukte updates.
- NTFS-rechten voor programma, configuratie en statusmap; lock tegen gelijktijdige uitvoering.
- Bestandloops en native commando's respecteren de tijdslimiet; taak heeft een maximale uitvoeringstijd.
- Links en junctions worden niet gevolgd; locaties buiten het lokale profiel en bekende OneDrive-locaties worden geweigerd.
- Wi-Fi-detectie gebruikt de Windows WLAN-API en is onafhankelijk van de taal van netsh-uitvoer.
- Windows-CI met parsercontrole, ScriptAnalyzer, C#-compilatie en geisoleerde Pester-tests.
- Volledig releasearchief met SHA256-checksum en bijgewerkte beheerdocumentatie.

### Migratie

- Losse `.ps1`- en `.bat`-bestanden zijn niet meer voldoende; pak het volledige archief uit.
- `ForceUpdate`, configureerbare taak-/bestandsnamen en zelfinstallatie bij cleanup zijn vervallen.
- Nieuwe statusbestanden staan in `state`. Legacy-mappen en bestaande Event Log-gegevens blijven behouden voor handmatige beoordeling.
- Nieuwe versies schrijven geen Windows Event Log-berichten meer.

### Validatie

- Systeemacties worden gemockt; bestandtests gebruiken alleen tijdelijke testdata.
- Echte installatie en opschoning op een Windows-VM/testlaptop zijn nog niet uitgevoerd.

## [1.6.3] - 2026-07-02

### Gewijzigd

- Leeftijdsfiltering voor gebruikersmappen aangepast. Oude bestanden worden verwijderd, maar oude mappen worden alleen verwijderd wanneer ze leeg zijn.
- Nieuwe helper `Remove-OldFolderItems` toegevoegd voor consistente folder-cleanup.
- `ForceUpdate` staat standaard weer op `$false`, zodat normale installaties versiecontrole gebruiken en geen onnodige backups maken.
- Downloads-detectie heeft een fallback via `%USERPROFILE%\Downloads` wanneer Shell COM niet beschikbaar is.
- Bestanden hernoemd naar `LeenlaptopSchoonmaak.ps1` en `Install-LeenlaptopSchoonmaak.bat`.
- Migratie-opruiming toegevoegd voor oude taaknamen en de oude geinstalleerde `opstart-script.ps1`.
- README, servicedeskhandleiding en AVG-documentatie herschreven in een zakelijke, operationele stijl.
- Batch fallback voor `MaxBackupCount` gelijkgetrokken met de PowerShell-default van 5.

### Validatie

- PowerShell parsercontrole uitgevoerd.
- `LeenlaptopSchoonmaak.ps1 -PrintConfig` uitgevoerd.
- PSScriptAnalyzer-regels uit de GitHub workflow uitgevoerd.
- `git diff --check` uitgevoerd.

## [1.6.2] - 2026-01-14

### Gewijzigd

- Configuratievalidatie toegevoegd met `Test-Configuration`.
- `MaxBackupCount` toegevoegd voor beperking van het aantal scriptbackups.
- SHA256-verificatie toegevoegd na het kopieren van het script naar de installatiemap.
- Backup-cleanup opgesplitst in retentiecontrole en maximaal-aantal-controle.
- Browsercleanup uitgebreid met extra retries en controle of processen echt zijn gestopt.
- Firefox krijgt meer pogingen bij afsluiten.
- Statusrapportage uitgebreid met voortgang per opschoonstap.
- Batch-installatie verbeterd met robuustere configuratie-uitlezing.

### Opgelost

- PowerShell 5.1 incompatibiliteit door gebruik van moderne ternary syntax verwijderd.
- Backuplimiet werkte niet consequent door een count- en flow-control probleem.
- `ForceUpdate` in de gekopieerde versie werd niet altijd teruggezet.
- Diverse logmeldingen aangepast zodat gevoelige details niet naar Windows Event Log gaan.

## [1.6.1] - 2025-12-07

### Gewijzigd

- Browsercleanup verbeterd voor Edge, Chrome en Firefox.
- Credentials-, sync- en sessiedata worden vollediger verwijderd.
- Desktopdetectie verbeterd bij installaties met administratorrechten.
- Statusweergave en servicedeskfeedback uitgebreid.

### Opgelost

- Fouten rond desktopdetectie bij actieve gebruikerssessies.
- Problemen met scheduled-task instellingen op oudere PowerShell-versies.
- Onnodige update-loops bij geforceerde updates.

## [1.6.0] - 2025-11-03

### Gewijzigd

- Installatiemap verplaatst van `%LOCALAPPDATA%\HiddenScripts` naar `C:\ProgramData\LeenlaptopSchoonmaak`.
- Scheduled task hernoemd van `Opstart-Script` naar `LeenlaptopSchoonmaak`.
- Event Log source hernoemd naar `LeenlaptopSchoonmaak`.
- Configuratie uitgebreid met afzonderlijke schakelaars voor browser-, Wi-Fi-, temp-, downloads-, documenten- en media-cleanup.
- Leeftijdsfiltering toegevoegd voor gebruikersmappen.
- Automatische migratie vanaf v1.5.0 toegevoegd.

### Impact

Deze versie bevat pad- en taaknaamwijzigingen. Herinstallatie via `Install-LeenlaptopSchoonmaak.bat` voert de migratie automatisch uit.

## [1.5.0] - 2025-10-23

### Gewijzigd

- AVG-gerichte herziening van logging en retentie.
- Logging van persoonsgegevens verwijderd of beperkt.
- Automatische logretentie van 30 dagen toegevoegd.
- Duidelijke SUCCES/FAIL-status toegevoegd voor servicedesk.

## [1.4.1] - 2025-10-03

### Status

- Pre-AVG versie.
- Upgrade naar 1.5.0 of hoger aanbevolen.
