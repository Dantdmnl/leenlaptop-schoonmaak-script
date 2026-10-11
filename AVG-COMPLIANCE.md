# Privacy en gegevensbeheer

Technische beschrijving voor Leenlaptop Schoonmaak 1.7.2, 11 oktober 2026. Organisaties bepalen zelf welke gegevens mogen worden verwijderd, welke bewaartermijnen passend zijn en wie het programma mag gebruiken.

## Welke gegevens worden verwijderd?

Het programma verwijdert lokale browseropslag, tijdelijke bestanden en oude downloads van het gekozen leenaccount. Documenten en media worden alleen verwijderd als deze onderdelen expliciet zijn ingeschakeld. Wi-Fi-profielen en firewallregels zijn apparaatinstellingen; wijzigingen daaraan kunnen ook andere gebruikers raken.

Browseropschoning verwijdert ook lokale bladwijzers, aanmeldingen, extensies en instellingen. Verwijdering is niet terug te draaien. Het programma voert geen beveiligde schijfwissing uit en verwijdert geen gegevens uit externe diensten. De installer toont beschikbare gebruikersprofielen om het doelaccount te kiezen; opschoning blijft beperkt tot dat account. Synchronisatiesoftware kan lokale verwijderingen doorgeven. Bekende OneDrive-locaties worden daarom geweigerd.

## Logboeken en rapporten

Opgeslagen rapporten bevatten de versie, actie, het UTC-tijdstip, de duur, exitcode en algemene resultaten per stap. Ze bevatten geen gebruikers-SID, configuratiepaden, Wi-Fi-namen, bestandsnamen, browsergeschiedenis of bestandsinhoud. Uitvoer van externe opdrachten wordt niet opgeslagen. Foutmeldingen en de interactieve accountkeuze verschijnen op de console en kunnen accountnamen, SID's en paden bevatten.

`config.json` bevat de SID van het doelaccount en eventuele Wi-Fi-uitzonderingen. Back-ups van de installatie kunnen deze configuratie en de oude taakdefinitie bevatten. Behandel de configuratie en back-ups daarom als beheerinformatie die tot personen herleidbare gegevens kan bevatten.

Vanaf 1.7.0 schrijft het programma geen nieuwe Windows Event Log-berichten. Bestaande Event Log-gegevens en logboeken uit eerdere versies worden niet automatisch verwijderd.

## Opslag en toegang

| Bestand | Locatie | Toegang |
| --- | --- | --- |
| Programmabestanden, configuratie, manifest | `C:\ProgramData\LeenlaptopSchoonmaak` | SYSTEM en beheerders volledig; doelaccount lezen/uitvoeren |
| Back-ups van de installatie | `backups` onder de installatiemap | SYSTEM en beheerders |
| Status en uitvoeringslogboeken | `state` onder de installatiemap | SYSTEM en beheerders volledig; doelaccount wijzigen |

De installer stelt hiervoor expliciete NTFS-rechten in. Het doelaccount kan rapporten wijzigen; deze vormen daarom geen onafhankelijk bewijs van de uitvoering. Het programma verstuurt geen rapporten naar externe diensten.

## Bewaartermijnen

Eerdere uitvoeringsrapporten en gearchiveerde logboeken worden standaard na 30 dagen verwijderd. Bij 5 MB wordt het actuele logboek gearchiveerd en begint een nieuw bestand. De laatste tekst- en JSON-status blijven beschikbaar tot de volgende uitvoering. Back-ups van de installatie worden standaard beperkt tot 30 dagen en maximaal vijf exemplaren. Het verwijderen van deze back-ups vereist administratorrechten.

Bewaartermijnen worden toegepast tijdens installatie en daadwerkelijke opschoning. Als het programma niet wordt uitgevoerd, worden deze bestanden niet opgeruimd. Oude installatiemappen, gebruikerssnelkoppelingen en logboeken uit eerdere versies vallen buiten deze bewaartermijnen. Beoordeel ze afzonderlijk na de migratie.

## Beheercontrole

Controleer na installatie het doelaccount, de toegangsrechten, ingeschakelde onderdelen en bewaartermijnen. Gebruik een tijdelijk testaccount voor acceptatietests. Informeer gebruikers over gegevensverwijdering en schakel automatische opschoning bij aanmelden alleen bewust in. Houd bij heruitgifte ook rekening met gegevens die buiten de ingestelde opschoning vallen.
