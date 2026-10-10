# Privacy en gegevensbeheer

Technische beschrijving voor Leenlaptop Schoonmaak 1.7.0, 10 oktober 2026. Organisaties bepalen zelf welke gegevens mogen worden verwijderd, welke bewaartermijnen passen en wie de utility mag gebruiken.

## Opschoonscope

De utility verwijdert lokale browseropslag, tijdelijke bestanden en oude downloads van het gekozen leenaccount. Documenten en media worden alleen verwijderd als deze onderdelen expliciet zijn ingeschakeld. Wi-Fi-profielen en firewallregels zijn apparaatinstellingen en kunnen ook andere gebruikers raken.

Browsercleanup verwijdert ook lokale bladwijzers, aanmeldingen, extensies en instellingen. Verwijdering is niet terug te draaien. De utility doet geen beveiligde schijfwissing, inventariseert geen andere gebruikersprofielen en verwijdert geen gegevens uit externe diensten. Synchronisatiesoftware kan lokale verwijderingen wel doorgeven; bekende OneDrive-locaties worden daarom geweigerd.

## Logging

Opgeslagen rapporten bevatten versie, actie, UTC-tijdstip, duur, exitcode en generieke resultaten per stap. Ze bevatten geen gebruikers-SID, configuratiepaden, Wi-Fi-namen, bestandsnamen, browsergeschiedenis of inhoud van bestanden. Native commando-uitvoer wordt niet opgeslagen. Technische uitzonderingen worden op de console getoond en kunnen wel paden bevatten.

`config.json` bevat de SID van het doelaccount en eventuele Wi-Fi-uitzonderingen. Installatiebackups kunnen deze configuratie en de oude taakdefinitie bevatten. Behandel configuratie en backups daarom als beheerinformatie met mogelijk herleidbare gegevens.

Vanaf 1.7.0 schrijft de utility geen nieuwe Windows Event Log-berichten. Bestaande Event Log-gegevens en oude logs uit eerdere versies worden niet automatisch verwijderd.

## Opslag en toegang

| Bestand | Locatie | Toegang |
| --- | --- | --- |
| Programmabestanden, configuratie, manifest | `C:\ProgramData\LeenlaptopSchoonmaak` | SYSTEM en beheerders volledig; doelaccount lezen/uitvoeren |
| Installatiebackups | `backups` onder de installatiemap | SYSTEM en beheerders |
| Status en uitvoeringslogs | `state` onder de installatiemap | SYSTEM en beheerders volledig; doelaccount wijzigen |

De installer stelt hiervoor expliciete NTFS-rechten in. Rapporten zijn niet bestand tegen wijzigingen door het doelaccount en vormen geen onafhankelijk auditbewijs. De utility verstuurt geen rapporten naar externe diensten.

## Retentie

Uitvoeringshistorie en geroteerde logs worden standaard na 30 dagen verwijderd. De actuele log wordt bij 5 MB geroteerd. De laatste tekst- en JSON-status blijven beschikbaar tot de volgende uitvoering. Installatiebackups worden standaard beperkt tot 30 dagen en maximaal vijf backups; daarvoor zijn administratorrechten nodig.

Retentie wordt toegepast tijdens installatie en daadwerkelijke opschoning. Een apparaat waarop de utility niet wordt uitgevoerd, ruimt geen bestanden op. Oude installatiemappen, gebruikerssnelkoppelingen en legacy-logs vallen buiten de nieuwe retentie en vragen een afzonderlijke beoordeling na migratie.

## Beheercontrole

Controleer na installatie het doelaccount, de ACL's, ingeschakelde onderdelen en retentie. Gebruik een wegwerpaccount voor acceptatietests. Informeer gebruikers over gegevensverwijdering en schakel automatische opschoning bij aanmelden alleen bewust in. Houd bij heruitgifte ook rekening met gegevens buiten de ingestelde opschoonscope.
