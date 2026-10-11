# Validatie van 1.7.1

Gecontroleerd op 11 oktober 2026.

## Geautomatiseerde controles

- Syntaxcontrole voor PowerShell 5.1, geselecteerde ScriptAnalyzer-regels en compilatie van de C#-helper.
- 44 Pester-tests met tijdelijke testbestanden en gesimuleerde systeemacties: accountkeuze, annuleren, profielinventarisatie, configuratie, migratie, herstel na mislukte updates, leeftijdsfilters, links, vergrendeling, status, bewaartermijnen en browseropslag met testprofielen.
- Native WLAN-structuurafmetingen en Unicode-marshaling zonder WLAN-functies aan te roepen.
- Integratietest op een tijdelijke Windows-machine van GitHub: inventarisatie van echte gebruikersprofielen, installatie, geplande taak, taakrechten, NTFS-rechten, snelkoppeling, opdrachtregel, rapportage, configuratiebehoud bij updates en beheer van taaktriggers. Alle opschoonfuncties staan uit. De test weigert uitvoering buiten GitHub Actions.

De integratietest controleert de ingestelde toegangsrechten. De test simuleert geen aanmelding als standaardgebruiker en geen fysieke USB-stick. De testmachine draait Windows Server, geen Windows 10/11. Installatie vanaf een USB-stick gebruikt hetzelfde kopieerproces; de fysieke controle staat in de acceptatietest.

## Onderzoeksbronnen

| Onderdeel | Officiele bron | Controle |
| --- | --- | --- |
| Accountkeuze | [Microsoft: Win32_UserProfile](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ee886409(v=vs.85)) | SID, profielpad en onderscheid tussen gebruikers- en systeemprofielen; de gekozen SID wordt voor installatie opnieuw gecontroleerd |
| Taakcontext en rechten | [Microsoft: Security Contexts for Tasks](https://learn.microsoft.com/en-us/windows/win32/taskschd/security-contexts-for-running-tasks) | Principal, interactieve context, hoogste bevoegdheden en afzonderlijke startrechten |
| Taak-DACL | [Microsoft: SetSecurityDescriptor](https://learn.microsoft.com/en-us/windows/win32/taskschd/registeredtask-setsecuritydescriptor) | Doelaccount mag lezen/starten; SYSTEM en beheerders houden volledige toegang |
| Wi-Fi-verwijdering | [Microsoft: WlanDeleteProfile](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/nf-wlanapi-wlandeleteprofile) | Unicode, letterlijke hoofdlettergevoelige naam, interface-GUID en foutcodes |
| Profielinventarisatie | [Microsoft: WlanGetProfileList](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/nf-wlanapi-wlangetprofilelist) | Pointerparameters en vrijgeven van door de API toegewezen geheugen |
| Native layout | [Microsoft: WLAN_INTERFACE_INFO](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ns-wlanapi-wlan_interface_info), [WLAN_PROFILE_INFO](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ns-wlanapi-wlan_profile_info) | GUID, vaste Unicode-buffer en 32-bit status/flags |
| Chrome-opslag | [Chromium: User Data Directory](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md) | Standaard Windows-opslag en meerdere profielen; afwijkende kanalen en locaties worden niet opgeschoond |
| Firefox-opslag | [Mozilla: Profiles](https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data) | Lokale profielen bevatten onder meer bladwijzers, instellingen en opgeslagen aanmeldingen |
| Omgeleide Edge-opslag | [Microsoft: UserDataDir](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/userdatadir) | Beleid kan de opslaglocatie wijzigen; alleen de standaardlocatie wordt opgeschoond |

## Grenzen

Er zijn geen echte gebruikersgegevens op de ontwikkelcomputer verwijderd. Het afsluiten van echte browsers, opnieuw starten na opschoning, verwijderen van Wi-Fi-profielen en herstellen van de firewall zijn niet getest. Browserprofielen met testgegevens controleren het verwijderen van bestanden, niet het gedrag van een echte browser. Afwijkende browserlocaties, andere gebruikersprofielen en gegevens buiten de ingestelde opschoning worden niet opgeschoond.

Voer de acceptatietest in `SERVICEDESK.md` uit met een tijdelijk testaccount en uw beheerconfiguratie. Een technisch geslaagde uitvoering bewijst niet dat alle gegevens op het apparaat zijn verwijderd.
