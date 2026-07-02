# Changelog

Alle relevante wijzigingen aan het leenlaptop-schoonmaakscript worden in dit bestand vastgelegd.

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
