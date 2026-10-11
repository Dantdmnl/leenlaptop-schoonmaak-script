# Leenlaptop Schoonmaak

Hulpprogramma voor Windows waarmee u een leenaccount na gebruik lokaal opschoont. Versie **1.7.1**, uitgebracht op **11 oktober 2026**. Vereist Windows 10/11 en Windows PowerShell 5.1.

## Gebruik

### Installeren, ook vanaf een USB-stick

1. Pak het volledige ZIP-archief uit in een map op de laptop of op een USB-stick. Laat alle bestanden bij elkaar staan; voer de installer niet rechtstreeks vanuit het ZIP-bestand uit.
2. Zorg dat het leenaccount al een gebruikersprofiel op deze laptop heeft. Meld u zo nodig eerst eenmaal aan met dat account.
3. Dubbelklik op `Install-LeenlaptopSchoonmaak.bat` en bevestig het Windows-beveiligingsvenster (UAC). De installer vraagt vooraf om administratorrechten. Een apart beheeraccount mag de installatie uitvoeren. Als u het verzoek annuleert, wordt niets geplaatst.
4. Kies het leenaccount uit de genummerde lijst. Controleer de accountnaam en profielmap en bevestig met `J`. Met `0` annuleert u zonder iets te wijzigen.
5. Controleer dat de installatie slaagt. Daarna kunt u de USB-stick verwijderen.

De installatie kopieert de programmabestanden naar `C:\ProgramData\LeenlaptopSchoonmaak` en stelt de geplande taak en bureaubladsnelkoppeling in, tenzij deze in de configuratie zijn uitgeschakeld. De taak en snelkoppeling verwijzen naar de lokale installatie, niet naar de USB-stick. Installatie verwijdert geen gebruikersgegevens.

### PowerShell

```powershell
# Alleen controleren; dit is ook de standaard zonder argumenten.
.\LeenlaptopSchoonmaak.ps1 -Check

# Bekijk de geplande stappen zonder iets te wijzigen, ook voor installatie.
.\LeenlaptopSchoonmaak.ps1 -Cleanup -WhatIf

# Kies het leenaccount uit een lijst; voer dit uit als administrator.
.\LeenlaptopSchoonmaak.ps1 -Install -Interactive

# Zonder vragen installeren, bijvoorbeeld bij geautomatiseerd beheer.
.\LeenlaptopSchoonmaak.ps1 -Install -TargetUser 'LAPTOP\leenaccount'
```

De keuzelijst toont beschikbare gebruikersprofielen op deze laptop, geen volledige lijst van accounts in de organisatie. Systeemprofielen en accounts die niet meer kunnen worden herkend, zijn niet selecteerbaar. Er is geen standaardkeuze. `-Interactive` en `-TargetUser` kunnen niet samen worden gebruikt.

Log vervolgens in als het doelaccount. Handmatig opschonen kan via **Leenlaptop Opschonen** op het openbare bureaublad of met:

```powershell
& 'C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1' -Cleanup
```

Opschoning verwijdert gegevens definitief. Browseropslag wordt volledig leeggemaakt, inclusief cookies, opgeslagen aanmeldingen, instellingen, extensies en lokale bladwijzers. Maak noodzakelijke gegevens vooraf elders beschikbaar. Dit is geen schijfwisprogramma of vervanging voor een herinstallatie.

Browseropschoning omvat de standaardopslaglocaties van Edge, Chrome en Firefox, inclusief de profielen binnen die locaties. Draagbare browsers en profielen waarvoor een andere opslaglocatie is ingesteld, vallen hierbuiten.

## Configuratie

Instellingen staan na installatie in `C:\ProgramData\LeenlaptopSchoonmaak\config.json`. Alleen beheerders kunnen dit bestand en de programmabestanden wijzigen. Het doelaccount heeft alleen schrijftoegang tot de statusmap.

Voor een eerste installatie kunt u een kopie van `config.example.json` opslaan als `config.json` naast de releasebestanden. Bij updates krijgt de configuratie van de bestaande installatie voorrang. Met `-ConfigPath` kiest u een ander JSON-bestand. Als dit bestand ontbreekt of ongeldig is, stopt de uitvoering.

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
| Tijdelijke bestanden | Bestanden verwijderen, lege submappen opruimen |
| Downloads | Alleen bestanden ouder dan 7 dagen en lege oude submappen |
| Documenten, Afbeeldingen, Video's, Muziek | Uit |
| Firewallreset | Aan; verwijdert aangepaste firewallregels |
| Geplande taak en snelkoppeling | Aan; taak standaard alleen handmatig starten |
| Automatisch bij aanmelden | Uit; vereist `RunAtLogon: true` en herinstallatie |
| Bewaartermijnen | 30 dagen; maximaal 5 back-ups van installaties |
| Uitvoeringstijd | 5 minuten |

Wi-Fi en firewallreset vereisen administratorrechten. Een taak met hoogste bevoegdheden geeft een standaardgebruiker geen administratorrechten. Deze onderdelen leveren zonder de benodigde rechten een gedeeltelijk resultaat op. Schakel ze uit wanneer een standaardaccount alleen zijn eigen gegevens moet opschonen.

Het programma werkt voor het gekozen doelaccount, niet voor alle profielen op een apparaat. Opschoning vanuit een ander account wordt geweigerd, ook bij een voorvertoning van een bestaande installatie. De taak gebruikt de aangemelde sessie van het doelaccount. Installatie met een apart beheeraccount verandert het gekozen doelaccount niet. Het doelaccount mag de taak lezen en starten, maar niet wijzigen.

Gebruikersmappen buiten het huidige lokale profiel en bekende OneDrive-locaties worden geweigerd. Junctions, symbolische links en andere reparse points worden niet gevolgd en tellen als onvolledige opschoning. Andere synchronisatiesoftware wordt niet automatisch herkend; controleer de opslaglocaties vooraf.

## Resultaten

| Exitcode | Betekenis |
| --- | --- |
| `0` | Geslaagd, een voorvertoning (`Planned`) of door de gebruiker geannuleerd (`Cancelled`) |
| `1` | Mislukt, configuratiefout of afgebroken uitvoering |
| `2` | Gedeeltelijk geslaagd; bijvoorbeeld vergrendelde bestanden of ontbrekende rechten |

De status geeft het technische resultaat van de ingeschakelde stappen weer. Een geslaagde installatie of opschoning betekent niet dat het hele apparaat schoon is. Uitgeschakelde onderdelen en andere gebruikersprofielen worden niet opgeschoond.

Statusbestanden staan onder `C:\ProgramData\LeenlaptopSchoonmaak\state`:

- `laatste_status.txt`: leesbare samenvatting;
- `laatste_status.json`: resultaat per stap en exitcode;
- `run_*.json`: uitvoeringshistorie;
- `log.txt`: kort uitvoeringslogboek.

`-Check`, `-PrintConfig` en `-WhatIf` schrijven geen logboeken, status- of vergrendelingsbestanden. De console kan configuratiepaden en instellingen tonen; opgeslagen rapporten bevatten geen gebruikersnamen, bestandsnamen of Wi-Fi-namen. Vanaf 1.7 worden geen nieuwe Windows Event Log-berichten geschreven.

Een vergrendelingsbestand voorkomt dat installatie en opschoning tegelijk worden uitgevoerd. De tijdslimiet wordt tussen stappen en tijdens het verwerken van bestanden gecontroleerd. Externe opdrachten worden bij overschrijding gestopt; op een lopende Windows-bestands- of CIM-aanroep moet het programma soms nog wachten. Taakplanner begrenst daarnaast de uitvoeringstijd van de taak. Opschoning is niet terug te draaien.

## Updates en migratie

Installeer een update vanuit een aparte map met de uitgepakte releasebestanden. Dat mag ook een map op een USB-stick zijn. Bestaande JSON-instellingen blijven behouden. Bij versies 1.5/1.6 leest het programma bekende instellingen met vaste waarden uit het oude script, zonder dat script uit te voeren. Voor instellingen die door code worden berekend, moet u zelf een JSON-configuratie aanleveren. Automatische opschoning bij aanmelden wordt bij deze migratie uitgeschakeld.

De installatie maakt back-ups van bestaande programmabestanden, de configuratie, de taak en de openbare snelkoppeling. Nieuwe bestanden worden eerst voorbereid en met SHA256 gecontroleerd. Na een geslaagde installatie worden de oude taak `Opstart-Script` en het oude script in de huidige installatiemap verwijderd. Bij een mislukte update worden de vorige bestanden en taak teruggezet. De back-ups staan in `backups`.

Een oude map `%LOCALAPPDATA%\HiddenScripts`, oude gebruikerssnelkoppelingen en bestaande Event Log-gegevens blijven behouden voor handmatige beoordeling. Verwijder deze na een gecontroleerde proef op een testlaptop. Bij aangepaste oude installatielocaties gebruikt u `-InstallPath`; dit pad moet eindigen op `LeenlaptopSchoonmaak`. `-ConfigPath` kan instellingen uit een voorbereide JSON-configuratie overnemen.

Voor opschoning controleert het programma aan de hand van `manifest.json` of de programmabestanden compleet en ongewijzigd zijn. Pas alleen `config.json` aan; wijzigingen aan programmabestanden vereisen herinstallatie. Deze controle kan beschadiging vaststellen, maar vervangt geen digitale ondertekening.

## Ontwikkeling en validatie

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Invoke-Tests.ps1
.\tools\New-ReleaseArchive.ps1
```

De 50 Pester-tests gebruiken uitsluitend tijdelijke bestanden en gesimuleerde systeemacties, inclusief browserprofielen met testgegevens en het aanvragen van administratorrechten. De automatische Windows-controles omvatten syntaxcontrole, geselecteerde ScriptAnalyzer-regels, compilatie van de C#-helper en deze tests. Daarnaast controleert een integratietest op een tijdelijke Windows-machine van GitHub de profielinventarisatie, installatie, taakregistratie, toegangsrechten, snelkoppeling, opdrachtregel, rapportage en updates. Alle opschoonfuncties staan tijdens die integratietest uit. De test weigert uitvoering buiten GitHub Actions.

Het afsluiten van echte browsers, verwijderen van Wi-Fi-profielen en herstellen van de firewall zijn niet getest. Controleer deze functies en uw beheerconfiguratie met een tijdelijk testaccount voordat u het programma breed inzet. Op de ontwikkelcomputer worden geen echte gebruikersgegevens opgeschoond. Zie [VALIDATION.md](VALIDATION.md) voor de uitgevoerde controles en bronnen, [SERVICEDESK.md](SERVICEDESK.md) voor de acceptatietest en [AVG-COMPLIANCE.md](AVG-COMPLIANCE.md) voor de technische privacymaatregelen. De release bevat het volledige ZIP-archief en `SHA256SUMS.txt`.
