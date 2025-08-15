# leenlaptop-schoonmaak-script

## Overzicht
Dit PowerShell-script is ontworpen om de opschoning en herconfiguratie van leenlaptops te automatiseren. Bij elke gebruikersaanmelding zorgt het script ervoor dat de laptop in een schone en gestandaardiseerde staat verkeert.

## Belangrijkste functies
- Zelfkopiëren naar een verborgen map (%LOCALAPPDATA%\HiddenScripts)
- Sluiten van browsers (Edge, Firefox, Chrome)
- Verwijderen van browserdata: cache, cookies, sessies en geschiedenis
- Verwijderen van Wi-Fi-profielen, behalve 'uw-wifi'
- Leegmaken van tijdelijke bestanden
- Herstellen van Windows Firewall naar standaardinstellingen
- Automatische logrotatie van logbestanden
- Loggen naar zowel bestand als Windows Event Log
- Registreren als geplande taak bij gebruikerslogon
- Eenmalige bureaubladsnelkoppeling: 'Terug naar start'

## Voorwaarden
- Windows 10 of hoger
- PowerShell 5.1 of hoger
- Uitvoeringsbeleid: 'RemoteSigned' of 'Bypass'
- Gebruikersaccount met rechten om geplande taken aan te maken

## Installatie-instructies
1. Plaats 'opstart-script.ps1' en 'initial-setup.bat' in dezelfde map.
2. Voer 'initial-setup.bat' uit als administrator.
3. Het script registreert zichzelf als geplande taak en kopieert zichzelf naar een verborgen locatie.

## Configuratie-opties
Pas de instellingen aan in 'opstart-script.ps1' voor specifieke configuraties zoals de naam van de verborgen map, toegestane Wi-Fi-profielen, en loginstellingen.

## Logging en Troubleshooting
- Logbestanden worden opgeslagen in %LOCALAPPDATA%\HiddenScripts\script.log.
- Controleer dit bestand voor foutmeldingen en herregistreer de taak indien nodig.

## Versie-informatie
De huidige versie van het script is zichtbaar bovenaan het scriptbestand, bijvoorbeeld: **VERSIE: 1.3.0**.
