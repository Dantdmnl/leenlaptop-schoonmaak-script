# Leenlaptop Schoonmaak

Windows-utility voor het lokaal opschonen van een leenaccount na gebruik. Versie **1.7.0**, uitgebracht op **10 oktober 2026**. Vereist Windows 10/11 en Windows PowerShell 5.1.

## Gebruik

Pak het volledige releasearchief uit. De PowerShell-entrypoint, module, C#-helper en voorbeeldconfiguratie moeten bij elkaar blijven.

```powershell
# Alleen controleren; dit is ook de standaard zonder argumenten.
.\LeenlaptopSchoonmaak.ps1 -Check

# Bekijk de geplande stappen zonder iets te wijzigen, ook voor installatie.
.\LeenlaptopSchoonmaak.ps1 -Cleanup -WhatIf

# Installeer als administrator voor een expliciet gekozen leenaccount.
.\LeenlaptopSchoonmaak.ps1 -Install -TargetUser 'LAPTOP\leenaccount'
```

Installatie verwijdert geen gebruikersgegevens. Het doelaccount moet al een lokaal profiel hebben: log er eerst eenmaal mee in. `Install-LeenlaptopSchoonmaak.bat` vraagt om hetzelfde account en moet als administrator worden gestart.

Log vervolgens in als het doelaccount. Handmatig opschonen kan via **Leenlaptop Opschonen** op het openbare bureaublad of met:

```powershell
& 'C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1' -Cleanup
```

Opschoning verwijdert gegevens definitief. Browseropslag wordt volledig leeggemaakt, inclusief cookies, opgeslagen aanmeldingen, instellingen, extensies en lokale bladwijzers. Maak noodzakelijke gegevens vooraf elders beschikbaar. Dit is geen schijfwisprogramma of vervanging voor een herinstallatie.

Browsercleanup omvat de standaard opslaglocaties van deze drie browsers, inclusief profielen binnen die locaties. Draagbare browsers en profielen die via command-line-opties elders zijn geplaatst vallen buiten de scope.

## Configuratie

Instellingen staan na installatie in `C:\ProgramData\LeenlaptopSchoonmaak\config.json`. Alleen beheerders kunnen dit bestand en de programmabestanden wijzigen. Het doelaccount kan alleen de statusmap beschrijven.

Voor een eerste installatie kunt u `config.example.json` kopieren naar `config.json` naast de releasebestanden. Bij updates krijgt de bestaande geinstalleerde configuratie voorrang. Met `-ConfigPath` kiest u expliciet een ander JSON-bestand. Een ontbrekend of ongeldig opgegeven bestand stopt de uitvoering.

Voorbeeld van enkele instellingen, onderdeel van een volledig JSON-object:

```json
{
  "EnableBrowserCleanup": true,
  "AllowedWiFi": ["kantoor-wifi"],
  "DownloadsMaxAgeDays": 7,
  "RunAtLogon": false,
  "EnableFirewallReset": false
}
```

Ontbrekende sleutels krijgen hun standaardwaarde. Onbekende sleutels, ongeldige typen en niet ondersteunde schema's worden geweigerd. `-PrintConfig` schrijft de effectieve configuratie als JSON naar de console.

| Onderdeel | Standaard |
| --- | --- |
| Browsers | Edge, Chrome en Firefox opschonen |
| Wi-Fi | Alle gevonden profielen verwijderen; `AllowedWiFi` bevat letterlijke, hoofdlettergevoelige uitzonderingen |
| Temp | Bestanden verwijderen, lege submappen opruimen |
| Downloads | Alleen bestanden ouder dan 7 dagen en lege oude submappen |
| Documenten, Afbeeldingen, Video's, Muziek | Uit |
| Firewallreset | Aan; verwijdert aangepaste firewallregels |
| Geplande taak en snelkoppeling | Aan; taak standaard alleen handmatig starten |
| Automatisch bij aanmelden | Uit; vereist `RunAtLogon: true` en herinstallatie |
| Retentie | 30 dagen; maximaal 5 installatiebackups |
| Uitvoeringstijd | 5 minuten |

Wi-Fi en firewallreset vereisen administratorrechten. Een taak met hoogste bevoegdheden geeft een standaardgebruiker geen administratorrechten. Deze onderdelen leveren zonder de benodigde rechten een gedeeltelijk resultaat op. Schakel ze uit wanneer een standaardaccount alleen zijn eigen gegevens moet opschonen.

De utility werkt voor een expliciet doelaccount, niet voor alle profielen op een apparaat. Uitvoering vanuit een ander account wordt geweigerd, ook bij een voorvertoning van een geconfigureerde installatie. De taak gebruikt een interactieve sessie van het doelaccount. Installatie met een apart beheeraccount verandert de doelgebruiker niet. Het doelaccount krijgt expliciet lees- en startrechten op de taak, maar geen wijzigingsrechten.

Gebruikersmappen buiten het huidige lokale profiel en bekende OneDrive-locaties worden geweigerd. Junctions, symbolische links en andere reparse points worden niet gevolgd en tellen als onvolledige opschoning. Andere synchronisatiesoftware wordt niet automatisch herkend; controleer de opslaglocaties vooraf.

## Resultaten

| Exitcode | Betekenis |
| --- | --- |
| `0` | Geslaagd, of een geslaagde voorvertoning (`Planned`) |
| `1` | Mislukt, configuratiefout of afgebroken uitvoering |
| `2` | Gedeeltelijk geslaagd; bijvoorbeeld vergrendelde bestanden of ontbrekende rechten |

De status is een technisch resultaat van de ingeschakelde stappen. Een succesvolle installatie of opschoning is geen verklaring dat het hele apparaat schoon is. Uitgeschakelde onderdelen en andere gebruikersprofielen vallen buiten de scope.

Statusbestanden staan onder `C:\ProgramData\LeenlaptopSchoonmaak\state`:

- `laatste_status.txt`: leesbare samenvatting;
- `laatste_status.json`: resultaat per stap en exitcode;
- `run_*.json`: uitvoeringshistorie;
- `log.txt`: korte operationele log.

`-Check`, `-PrintConfig` en `-WhatIf` schrijven geen logs, status of lockbestanden. De console kan configuratiepaden en instellingen tonen; opgeslagen rapporten bevatten geen gebruikersnamen, bestandsnamen of Wi-Fi-namen. Vanaf 1.7 worden geen nieuwe Windows Event Log-berichten geschreven.

Een bestandslock voorkomt overlappende installatie en opschoning. De tijdslimiet wordt tussen stappen en tijdens bestandloops gecontroleerd; native commando's worden bij overschrijding gestopt. Een al lopende Windows-bestands- of CIM-aanroep kan nog moeten terugkeren. Taakplanner stelt daarnaast een harde uitvoeringstijd in. Opschoning is niet terug te draaien.

## Updates en migratie

Installeer een update vanuit een aparte uitgepakte releasemap. De utility bewaart bestaande JSON-instellingen. Bij versies 1.5/1.6 leest hij bekende letterlijke instellingen uit het oude script zonder dat script uit te voeren. Dynamische instellingen vereisen een expliciet JSON-bestand. Automatische uitvoering bij aanmelden wordt bij deze migratie uitgeschakeld.

De installatie maakt een backup van bestaande programmabestanden, configuratie, taak en openbare snelkoppeling. Nieuwe bestanden worden eerst voorbereid en met SHA256 gecontroleerd. Na succesvolle installatie worden de oude taak `Opstart-Script` en het oude script in de huidige installatiemap verwijderd. Bij een mislukte update worden de vorige bestanden en taak teruggezet. Backups staan in `backups`.

Een oude map `%LOCALAPPDATA%\HiddenScripts`, oude gebruikerssnelkoppelingen en bestaande Event Log-gegevens blijven behouden voor handmatige beoordeling. Verwijder deze na een gecontroleerde proef op een testlaptop. Bij aangepaste oude installatielocaties gebruikt u `-InstallPath`; dit pad moet eindigen op `LeenlaptopSchoonmaak`. `-ConfigPath` kan instellingen uit een voorbereide JSON-configuratie overnemen.

Het geinstalleerde manifest controleert pakketintegriteit voor opschoning. Pas alleen `config.json` aan; wijzigingen aan programmabestanden vereisen herinstallatie. De manifestcontrole detecteert beschadiging, maar vervangt geen digitale ondertekening.

## Ontwikkeling en validatie

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-Tests.ps1
.\tools\New-ReleaseArchive.ps1
```

De 34 Pester-tests gebruiken uitsluitend tijdelijke bestanden en gemockte systeemacties, inclusief nep-browserprofielen. Windows-CI voert parsercontrole, geselecteerde ScriptAnalyzer-regels, C#-compilatie en deze tests uit. Daarnaast controleert een integratietest op de tijdelijke GitHub Windows-runner echte installatie, taakregistratie, taakrechten, NTFS-rechten, snelkoppeling, CLI, rapportage en updates. Alle opschoonfuncties zijn daar uitgeschakeld. Deze integratietest weigert uitvoering buiten GitHub Actions.

Live browserafsluiting, Wi-Fi-verwijdering en firewallreset zijn niet uitgevoerd. Controleer deze functies en de eigen beheerconfiguratie op een wegwerpaccount voor brede uitrol. Er worden geen echte gebruikersgegevens op de ontwikkelcomputer opgeschoond. Zie [VALIDATION.md](VALIDATION.md) voor testscope en onderzoeksbronnen, [SERVICEDESK.md](SERVICEDESK.md) voor de acceptatietest en [AVG-COMPLIANCE.md](AVG-COMPLIANCE.md) voor de technische privacymaatregelen. De release bevat een volledig ZIP-archief en `SHA256SUMS.txt`.
