# Servicedeskhandleiding

Leenlaptop Schoonmaak 1.7.0-rc.1, 10 oktober 2026. Releasecandidate voor acceptatie op een testapparaat.

## Installeren

1. Pak het volledige releasearchief uit in een tijdelijke map.
2. Controleer welk leenaccount moet worden opgeschoond en log er eenmaal mee in.
3. Start de installer als administrator en geef het doelaccount op, bijvoorbeeld `LAPTOP\leenaccount`.
4. Controleer dat de installatie eindigt met exitcode 0.
5. Log in als het doelaccount. Controleer eerst met `-Check` en bekijk daarna `-Cleanup -WhatIf`.

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

De installatie koppelt de taak aan de SID van het gekozen leenaccount. Een apart beheeraccount mag installeren; opschonen als dat beheeraccount wordt geweigerd. Een standaardaccount kan zijn eigen bestanden opschonen, maar krijgt via de taak geen extra administratorrechten. Wi-Fi en firewallreset vereisen wel die rechten en leveren anders een gedeeltelijke status op.

De programmabestanden en configuratie kunnen alleen door beheerders worden gewijzigd. De doelgebruiker kan de statusmap beschrijven. Statusbestanden zijn daarom geen fraudebestendige auditregistratie.

## Instellingen wijzigen

Wijzig als administrator `C:\ProgramData\LeenlaptopSchoonmaak\config.json`. Booleanwaarden zijn `true` of `false`, aantallen zijn gehele getallen en uitzonderingslijsten zijn JSON-arrays. Controleer wijzigingen met `-Check`.

Wijzigingen aan opschooninstellingen gelden bij de volgende uitvoering. Instellingen voor snelkoppeling, geplande taak, doelaccount en uitvoeringstijd van de taak vereisen herinstallatie vanuit een uitgepakte release. `RunAtLogon` staat standaard uit. Inschakelen betekent gegevens verwijderen bij aanmelden; informeer gebruikers vooraf over dit gedrag.

## Problemen

| Probleem | Actie |
| --- | --- |
| Ander account dan doelaccount | Meld het doelaccount aan; gebruik een beheeraccount alleen voor installatie |
| Gedeeltelijk resultaat | Controleer stapresultaten, benodigde rechten, locks en overgeslagen links |
| Gewijzigd of onvolledig pakket | Herinstalleer vanuit het volledige releasearchief |
| Omgeleide gebruikersmap | Controleer de opslaglocatie; de utility weigert locaties buiten het lokale profiel en bekende OneDrive-mappen |
| Utility al actief | Wacht op de bestaande uitvoering; verwijder de lock niet tijdens gebruik |
| Taak start niet | Controleer dat het doelaccount is aangemeld en de taak aanwezig is |
| Tijdslimiet bereikt | Onderzoek de omvang en locks; verhoog daarna eventueel de limiet en werk de taak bij |
| Geen nieuw rapport | Controleer consolefout, taskresultaat en schrijftoegang; een oud rapport hoort niet bij de huidige poging |

Bij een mislukte installatie worden bestanden en taak uit de backup hersteld. Als ook herstel faalt, blijft de backup in `backups` staan. Bewaar de foutmelding en herstel eerst op een testapparaat. Kopieer niet zomaar losse programmabestanden naar de installatiemap: de manifestcontrole zal dan falen.

## Acceptatietest op een wegwerpaccount

Gebruik een Windows-VM of testlaptop met gegevens die verwijderd mogen worden.

- Installeer met een apart beheeraccount voor een aangemeld testaccount. Controleer taakprincipal, ACL's en snelkoppeling.
- Controleer dat installatie, gewone start en `-WhatIf` geen browserdata of testbestanden verwijderen.
- Maak meerdere browserprofielen met tijdelijke geschiedenis, opgeslagen aanmeldingen en bladwijzers. Controleer de volledige lokale browseropslag na cleanup.
- Plaats oude en recente bestanden in Downloads, inclusief een oude map met een recent bestand. Alleen de oude bestanden mogen verdwijnen.
- Controleer dat een standaardaccount gedeeltelijk resultaat krijgt voor ingeschakelde beheeracties.
- Controleer op een geschikte testconfiguratie Wi-Fi-uitzonderingen en firewallreset.
- Upgrade vanaf 1.6.3 met afwijkende instellingen. Controleer behoud van configuratie, backups en verwijdering van de oude taak na succesvolle installatie.
- Start twee uitvoeringen tegelijk en controleer lock en status.
- Test eventueel automatisch aanmelden pas nadat handmatige opschoning is goedgekeurd.

Deze acceptatietest is geen onderdeel van de lokale ontwikkeltests en is voor 1.7.0 nog niet uitgevoerd. Geef bij escalatie de versie, actie, exitcode en laatste rapport mee; deel de configuratie alleen wanneer de Wi-Fi-uitzonderingen en doelaccountinformatie nodig zijn.
