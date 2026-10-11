# Changelog

Alle relevante wijzigingen aan het leenlaptop-schoonmaakscript worden in dit bestand vastgelegd.

## [1.7.3] - In voorbereiding

- Voorbeeldconfiguratie is geen verplicht programmabestand meer. Installatie werkt ook wanneer `config.example.json` is hernoemd naar `config.json`; de controle van programmabestanden blijft behouden.
- Duidelijkere installer met drie stappen, gegroepeerde instellingen, leeftijdsgrenzen naast de mappen, herkenbare waarschuwingen en Nederlandstalige resultaten.
- Het overzicht vermeldt expliciet wanneer opschoning start en wanneer de bestaande configuratie voorrang heeft.
- Vier tests toegevoegd; 64 tests in totaal. De Windows-integratietest installeert nu zonder voorbeeldbestand.

## [1.7.2] - 2026-10-11

Deze release volgt op 1.7.0 en bevat ook de verbeteringen uit de ingetrokken versie 1.7.1.

- `EnableStartupTask` hernoemd naar `EnableScheduledTask`. Oude JSON-configuraties en scripts blijven ondersteund; herinstallatie slaat alleen de nieuwe sleutel op.
- Automatisch opschonen bij aanmelden zonder geplande taak wordt geweigerd, net als tegenstrijdige oude en nieuwe taaksleutels.
- De interactieve installer toont de geladen configuratie met Nederlandse labels, bronbestand, installatiemap en waarschuwingen voor gegevensverwijdering.
- Definitieve toestemming wordt pas na het configuratieoverzicht gevraagd. Annuleren wijzigt niets; geautomatiseerde installatie blijft zonder vragen werken.
- Tien tests toegevoegd; 60 tests in totaal. De Windows-integratietest controleert ook migratie van de oude JSON-taaksleutel.

## [1.7.1] - 2026-10-11 (ingetrokken)

De GitHub-release is ingetrokken. De onderstaande wijzigingen blijven onderdeel van de broncode en volgende versie.

- Interactieve installatie met een genummerde lijst van beschikbare gebruikersprofielen, controle van de gekozen SID en expliciete bevestiging.
- Annuleren en opnieuw kiezen zonder installatie; `-TargetUser` blijft beschikbaar voor geautomatiseerd beheer.
- De batchinstaller gebruikt de accountkeuzelijst. De gekozen profielmap wordt ook gebruikt bij migratie van oude instellingen.
- Handleidingen herschreven in duidelijker Nederlands, met een installatieprocedure voor USB-sticks en uitleg over de lokale installatie.
- Privacybeschrijving aangepast aan de profielinventarisatie tijdens installatie.
- De batchinstaller vraagt vooraf om administratorrechten via UAC; annuleren stopt de installatie. Rechtstreeks gebruik van `-Install` controleert de rechten voor de accountkeuze.
- Zestien tests toegevoegd voor UAC, bronpaden, accountkeuze, invoercontrole, annuleren, migratie en profielinventarisatie; 50 tests in totaal.
- Profielinventarisatie toegevoegd aan de integratietest op de tijdelijke Windows-machine van GitHub.

## [1.7.0] - 2026-10-10

Stabiele release van het hulpprogramma met afzonderlijke installatie-, controle- en opschoonacties.

### Gewijzigd sinds rc.1

- Doelaccount krijgt expliciete lees- en startrechten op de geplande taak; oude taakrechten worden bij herstel teruggezet.
- Padcontrole omvat bestaande bovenliggende mappen van nog niet aangemaakte locaties. Installatie weigert programmabestanden die mappen of links zijn.
- Voorvertoning vanuit een ander account dan de geconfigureerde doelgebruiker wordt geweigerd.
- Tests uitgebreid met browserprofielen met testgegevens en controle van de native WLAN-geheugenindeling: 34 afzonderlijke tests.
- Integratietest op een tijdelijke Windows-machine van GitHub voor installatie, taakregistratie, toegangsrechten, snelkoppeling, opdrachtregel, rapportage, updates en taaktriggers. Alle opschoonfuncties staan tijdens deze test uit.
- API-gedrag en browseropslaglocaties gecontroleerd aan de hand van primaire documentatie; bronnen en testgrenzen vastgelegd in `VALIDATION.md`.

Het afsluiten van echte browsers, verwijderen van Wi-Fi-profielen en herstellen van de firewall zijn niet getest. Controle in de eigen beheeromgeving blijft nodig voordat het programma breed wordt ingezet.


## [1.7.0-rc.1] - 2026-10-10

Voorlopige release; echte installatie en opschoning vereisen nog een acceptatietest op een testapparaat.

### Gewijzigd

- Installatie, controle en opschoning zijn afzonderlijke acties; zonder argumenten wordt alleen gecontroleerd.
- Externe JSON-configuratie met typevalidatie en behoud van instellingen bij updates.
- Migratie leest letterlijke instellingen uit oude scripts zonder deze uit te voeren.
- Doelaccount vastgelegd op basis van SID; opschoning vanuit een ander account wordt geweigerd.
- Geplande taak gebruikt de interactieve sessie van het doelaccount. Automatische uitvoering bij aanmelden vereist expliciete configuratie.
- Volledige lokale browseropslag wordt gewist, inclusief meerdere en aangepaste profielen.
- Resultaten per stap, JSON-rapporten en exitcodes voor geslaagd, gedeeltelijk geslaagd en mislukt.
- `-WhatIf` zonder installatie-, log- of statuswijzigingen.
- SHA256-controle, pakketmanifest, back-ups van installaties en herstel van bestanden en taak bij mislukte updates.
- NTFS-rechten voor programma, configuratie en statusmap; vergrendeling tegen gelijktijdige uitvoering.
- Verwerking van bestanden en externe opdrachten houdt rekening met de tijdslimiet; de taak heeft een maximale uitvoeringstijd.
- Links en junctions worden niet gevolgd; locaties buiten het lokale profiel en bekende OneDrive-locaties worden geweigerd.
- Wi-Fi-detectie gebruikt de Windows WLAN-API en is onafhankelijk van de taal van netsh-uitvoer.
- Automatische Windows-controles met syntaxcontrole, ScriptAnalyzer, C#-compilatie en afzonderlijke Pester-tests.
- Volledig releasearchief met SHA256-controlebestand en bijgewerkte beheerdocumentatie.

### Migratie

- Losse `.ps1`- en `.bat`-bestanden zijn niet meer voldoende; pak het volledige archief uit.
- `ForceUpdate`, instelbare taak- en bestandsnamen en zelfinstallatie bij opschoning zijn vervallen.
- Nieuwe statusbestanden staan in `state`. Oude mappen en bestaande Event Log-gegevens blijven behouden voor handmatige beoordeling.
- Nieuwe versies schrijven geen Windows Event Log-berichten meer.

### Validatie

- Systeemacties worden gesimuleerd; bestandstests gebruiken alleen tijdelijke testgegevens.
- Echte installatie en opschoning op een Windows-VM/testlaptop zijn nog niet uitgevoerd.

## [1.6.3] - 2026-07-02

### Gewijzigd

- Leeftijdsfiltering voor gebruikersmappen aangepast. Oude bestanden worden verwijderd, maar oude mappen worden alleen verwijderd wanneer ze leeg zijn.
- Hulpfunctie `Remove-OldFolderItems` toegevoegd om mappen op dezelfde manier op te schonen.
- `ForceUpdate` staat standaard weer op `$false`, zodat normale installaties versiecontrole gebruiken en geen onnodige back-ups maken.
- Bij het bepalen van de downloadmap wordt `%USERPROFILE%\Downloads` gebruikt wanneer Shell COM niet beschikbaar is.
- Bestanden hernoemd naar `LeenlaptopSchoonmaak.ps1` en `Install-LeenlaptopSchoonmaak.bat`.
- Bij migratie worden oude taaknamen en de eerdere installatie van `opstart-script.ps1` opgeruimd.
- README, servicedeskhandleiding en AVG-documentatie herschreven in een zakelijke, operationele stijl.
- De terugvalwaarde voor `MaxBackupCount` in het batchbestand gelijkgetrokken met de PowerShell-standaardwaarde van 5.

### Validatie

- PowerShell-syntaxcontrole uitgevoerd.
- `LeenlaptopSchoonmaak.ps1 -PrintConfig` uitgevoerd.
- PSScriptAnalyzer-regels uit de GitHub-workflow uitgevoerd.
- `git diff --check` uitgevoerd.

## [1.6.2] - 2026-01-14

### Gewijzigd

- Configuratievalidatie toegevoegd met `Test-Configuration`.
- `MaxBackupCount` toegevoegd om het aantal back-ups van het script te beperken.
- SHA256-controle toegevoegd nadat het script naar de installatiemap is overgezet.
- Opschoning van back-ups opgesplitst in controle van bewaartermijn en maximumaantal.
- Browseropschoning uitgebreid met extra pogingen en controle of processen echt zijn gestopt.
- Firefox krijgt meer pogingen bij afsluiten.
- Statusrapportage uitgebreid met voortgang per opschoonstap.
- Installatie via het batchbestand verbeterd met betrouwbaarder uitlezen van de configuratie.

### Opgelost

- Incompatibiliteit met PowerShell 5.1 door gebruik van de moderne voorwaardelijke operator verholpen.
- Back-uplimiet werkte niet consequent door fouten in de telling en uitvoeringsvolgorde.
- `ForceUpdate` in de gekopieerde versie werd niet altijd teruggezet.
- Diverse logmeldingen aangepast zodat gevoelige details niet naar Windows Event Log gaan.

## [1.6.1] - 2025-12-07

### Gewijzigd

- Browseropschoning verbeterd voor Edge, Chrome en Firefox.
- Aanmeldings-, synchronisatie- en sessiegegevens worden vollediger verwijderd.
- Detectie van de bureaubladmap verbeterd bij installaties met administratorrechten.
- Statusweergave en informatie voor de servicedesk uitgebreid.

### Opgelost

- Fouten bij het bepalen van de bureaubladmap tijdens actieve gebruikerssessies.
- Problemen met instellingen van geplande taken op oudere PowerShell-versies.
- Onnodig herhaalde updates bij geforceerde updates.

## [1.6.0] - 2025-11-03

### Gewijzigd

- Installatiemap verplaatst van `%LOCALAPPDATA%\HiddenScripts` naar `C:\ProgramData\LeenlaptopSchoonmaak`.
- Geplande taak hernoemd van `Opstart-Script` naar `LeenlaptopSchoonmaak`.
- Event Log-bron hernoemd naar `LeenlaptopSchoonmaak`.
- Configuratie uitgebreid met afzonderlijke schakelaars voor het opschonen van browsers, Wi-Fi-profielen, tijdelijke bestanden, downloads, documenten en media.
- Leeftijdsfiltering toegevoegd voor gebruikersmappen.
- Automatische migratie vanaf v1.5.0 toegevoegd.

### Impact

Deze versie bevat pad- en taaknaamwijzigingen. Herinstallatie via `Install-LeenlaptopSchoonmaak.bat` voert de migratie automatisch uit.

## [1.5.0] - 2025-10-23

### Gewijzigd

- Logboeken en bewaartermijnen herzien met aandacht voor de AVG.
- Vastleggen van persoonsgegevens verwijderd of beperkt.
- Automatische bewaartermijn van 30 dagen voor logboeken toegevoegd.
- Duidelijke SUCCES/FAIL-status toegevoegd voor de servicedesk.

## [1.4.1] - 2025-10-03

### Status

- Versie van voor de privacyherziening.
- Upgrade naar 1.5.0 of hoger aanbevolen.
