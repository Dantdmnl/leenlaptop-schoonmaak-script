# Servicedeskhandleiding

Leenlaptop Schoonmaak 1.7.3, in voorbereiding.

## Installeren

1. Pak het volledige ZIP-archief uit in een map op de laptop of op een USB-stick. Laat alle bestanden bij elkaar staan.
2. Zorg dat het leenaccount al een gebruikersprofiel heeft. Meld u zo nodig eerst eenmaal aan met dit account.
3. Dubbelklik op `Install-LeenlaptopSchoonmaak.bat`. Bevestig eerst het Windows-beveiligingsvenster (UAC), eventueel met een apart beheeraccount. Kies daarna het leenaccount en controleer de accountnaam en profielmap. Ga door met `J`, kies opnieuw met `N` of annuleer met `0`. Controleer vervolgens het configuratieoverzicht en bevestig de installatie met `J`. Bij deze laatste vraag annuleren `N` en `0` zonder wijzigingen.
4. Controleer dat de status `Success` is en de exitcode `0`. Annuleren geeft ook exitcode `0`, maar de status `Cancelled`; dan is niets geplaatst.
5. Verwijder de USB-stick zodra de installatie is geslaagd. Het programma staat nu lokaal in `C:\ProgramData\LeenlaptopSchoonmaak`; de taak en snelkoppeling hebben de stick niet meer nodig.
6. Meld u aan met het doelaccount. Controleer eerst met `-Check` en bekijk daarna de geplande opschoning met `-Cleanup -WhatIf`.

```powershell
$utility = 'C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1'
& $utility -Check
& $utility -Cleanup -WhatIf
```

Installatie voert geen opschoning uit. Een gewone start zonder argumenten controleert alleen. De snelkoppeling op het openbare bureaublad start wel de opschoning, via de geplande taak wanneer die is ingeschakeld. Gebruik die alleen wanneer het doelaccount is aangemeld. Gebruik `Get-ScheduledTaskInfo` om een handmatig gestarte taak te controleren; de snelkoppeling wacht niet op het resultaat.

## Opschonen na gebruik

1. Maak te bewaren gegevens buiten het leenaccount beschikbaar.
2. Controleer de instellingen in `config.json`, waaronder firewallreset en Wi-Fi-uitzonderingen.
3. Start **Leenlaptop Opschonen** of voer `-Cleanup` uit als het doelaccount.
4. Controleer het tijdstip, de actie en alle stapresultaten in de laatste status.

```powershell
Get-Content 'C:\ProgramData\LeenlaptopSchoonmaak\state\laatste_status.txt'
Get-Content 'C:\ProgramData\LeenlaptopSchoonmaak\state\laatste_status.json' -Raw | ConvertFrom-Json
Get-ScheduledTaskInfo -TaskName 'LeenlaptopSchoonmaak'
```

Exitcode 0 is geslaagd, 1 is mislukt en 2 is gedeeltelijk geslaagd. `Planned` betekent dat er niets is uitgevoerd. Een installatieresultaat bewijst niet dat er is opgeschoond. Beoordeel de status samen met de ingeschakelde onderdelen.

## Account en rechten

De installatie koppelt de taak aan de SID van het gekozen leenaccount. Dat account mag de taak lezen en starten, maar niet wijzigen. Een apart beheeraccount mag installeren; opschonen vanuit dat account wordt geweigerd. Een standaardaccount kan zijn eigen bestanden opschonen, maar krijgt via de taak geen extra administratorrechten. Het verwijderen van Wi-Fi-profielen en herstellen van de firewall vereisen die rechten wel en leveren anders een gedeeltelijk resultaat op.

Alleen beheerders mogen de programmabestanden en configuratie wijzigen. Het doelaccount heeft schrijftoegang tot de statusmap. Statusbestanden zijn daarom geen onafhankelijk bewijs van de uitvoering.

## Instellingen wijzigen

Wijzig als administrator `C:\ProgramData\LeenlaptopSchoonmaak\config.json`. Booleanwaarden zijn `true` of `false`, aantallen zijn gehele getallen en uitzonderingslijsten zijn JSON-arrays. Controleer wijzigingen met `-Check`.

Wijzigingen aan opschooninstellingen gelden bij de volgende uitvoering. Instellingen voor snelkoppeling, geplande taak, doelaccount en uitvoeringstijd van de taak vereisen herinstallatie vanuit een uitgepakte release. `RunAtLogon` staat standaard uit. Inschakelen betekent gegevens verwijderen bij aanmelden; informeer gebruikers vooraf over dit gedrag.

`EnableScheduledTask` schakelt de geplande taak in; `RunAtLogon` voegt automatisch starten bij aanmelden toe. Zonder geplande taak is automatisch starten ongeldig. De oude configuratiesleutel `EnableStartupTask` blijft leesbaar en wordt bij herinstallatie vervangen door `EnableScheduledTask`. Annuleer bij ongewenste instellingen het installatieoverzicht en wijzig het getoonde bronbestand voordat u opnieuw installeert.

## Problemen

| Probleem | Actie |
| --- | --- |
| `Releasebestand ontbreekt: config.example.json` in 1.7.2 | Bewaar uw aangepaste `config.json` en maak daarnaast een kopie met de naam `config.example.json`. Vanaf 1.7.3 is dit voorbeeldbestand optioneel |
| UAC geannuleerd of administratorrechten ontbreken | Start de installer opnieuw en bevestig UAC. Voor rechtstreeks gebruik van `-Install` opent u PowerShell als administrator |
| Ander account dan doelaccount | Meld het doelaccount aan; gebruik een beheeraccount alleen voor installatie |
| Leenaccount ontbreekt in de lijst | Meld u eerst eenmaal aan met dit account; controleer of het account nog bestaat en het profiel lokaal beschikbaar is |
| Gedeeltelijk resultaat | Controleer resultaten per stap, benodigde rechten, vergrendelde bestanden en overgeslagen links |
| Gewijzigd of onvolledig pakket | Herinstalleer vanuit het volledige releasearchief |
| Omgeleide gebruikersmap | Controleer de opslaglocatie; het programma weigert locaties buiten het lokale profiel en bekende OneDrive-mappen |
| Programma al actief | Wacht tot de bestaande uitvoering klaar is; verwijder het vergrendelingsbestand niet tijdens gebruik |
| Taak start niet | Controleer dat het doelaccount is aangemeld en de taak aanwezig is |
| Tijdslimiet bereikt | Controleer de hoeveelheid gegevens en vergrendelde bestanden; verhoog zo nodig de limiet en werk de taak bij |
| Geen nieuw rapport | Controleer de foutmelding, het taakresultaat en de schrijftoegang; een oud rapport hoort niet bij de huidige poging |

Bij een mislukte installatie worden de bestanden en taak uit de back-up hersteld. Als ook dat herstel mislukt, blijft de back-up in `backups` staan. Bewaar de foutmelding en probeer herstel eerst op een testapparaat. Plaats niet zomaar losse programmabestanden in de installatiemap: daardoor mislukt de controle aan de hand van het manifest.

## Acceptatietest met een tijdelijk testaccount

Gebruik een Windows-VM of testlaptop met gegevens die verwijderd mogen worden.

- Installeer vanaf een USB-stick met een apart beheeraccount voor het testaccount. Controleer de accountkeuze, taakcontext, toegangsrechten en snelkoppeling. Verwijder de stick en controleer de lokale installatie.
- Annuleer de accountkeuze en controleer dat de installatie ongewijzigd blijft.
- Annuleer UAC en controleer dat geen accountkeuze of installatie begint. Start daarna opnieuw en bevestig het verzoek, ook met een apart beheeraccount.
- Controleer dat installatie, starten zonder argumenten en `-WhatIf` geen browsergegevens of testbestanden verwijderen.
- Maak meerdere browserprofielen met testgeschiedenis, opgeslagen aanmeldingen en bladwijzers. Controleer de volledige lokale browseropslag na opschoning.
- Plaats oude en recente bestanden in Downloads, inclusief een oude map met een recent bestand. Alleen de oude bestanden mogen verdwijnen.
- Controleer dat een standaardaccount gedeeltelijk resultaat krijgt voor ingeschakelde beheeracties.
- Controleer op een geschikte testconfiguratie Wi-Fi-uitzonderingen en firewallreset.
- Werk versie 1.6.3 met afwijkende instellingen bij. Controleer dat de configuratie behouden blijft, back-ups worden gemaakt en de oude taak pas na een geslaagde installatie wordt verwijderd.
- Start twee uitvoeringen tegelijk en controleer de vergrendeling en status.
- Test automatische opschoning bij aanmelden pas nadat handmatige opschoning is goedgekeurd.

Installatie, taakregistratie, bestandsrechten en updates worden op een tijdelijke Windows-machine van GitHub getest. De volledige acceptatietest met echte browsers, Wi-Fi en firewall is niet uitgevoerd en moet in de eigen beheeromgeving plaatsvinden. Vermeld bij een ondersteuningsverzoek de versie, actie en exitcode en voeg het laatste rapport toe. Deel de configuratie alleen als de Wi-Fi-uitzonderingen en accountgegevens nodig zijn.
