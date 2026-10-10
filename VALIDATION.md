# Validatie van 1.7.0

Gecontroleerd op 10 oktober 2026.

## Geautomatiseerde controles

- PowerShell 5.1-parser, geselecteerde ScriptAnalyzer-regels en compilatie van de C#-helper.
- 34 Pester-tests met tijdelijke testbestanden en gemockte systeemacties: configuratie, migratie, updateherstel, leeftijdsfilters, links, locks, status, retentie en browseropslag met nep-profielen.
- Native WLAN-structuurafmetingen en Unicode-marshaling zonder WLAN-functies aan te roepen.
- Integratie op de tijdelijke Windows-runner van GitHub: echte installatie, geplande taak, expliciete taakrechten, NTFS-rechten, snelkoppeling, geinstalleerde CLI, rapportage, configuratiebehoud bij updates en triggerbeheer. Alle opschoonfuncties staan uit. De test weigert uitvoering buiten GitHub Actions.

De integratietest controleert de expliciete ACL-regels. Hij simuleert geen interactieve aanmelding als standaardgebruiker. Het CI-platform is de GitHub Windows Server-runner, geen fysieke Windows 10/11-leenlaptop.

## Onderzoeksbronnen

| Onderdeel | Officiele bron | Controle |
| --- | --- | --- |
| Taakcontext en rechten | [Microsoft: Security Contexts for Tasks](https://learn.microsoft.com/en-us/windows/win32/taskschd/security-contexts-for-running-tasks) | Principal, interactieve context, hoogste bevoegdheden en afzonderlijke startrechten |
| Taak-DACL | [Microsoft: SetSecurityDescriptor](https://learn.microsoft.com/en-us/windows/win32/taskschd/registeredtask-setsecuritydescriptor) | Doelaccount mag lezen/starten; SYSTEM en beheerders houden volledige toegang |
| Wi-Fi-verwijdering | [Microsoft: WlanDeleteProfile](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/nf-wlanapi-wlandeleteprofile) | Unicode, letterlijke hoofdlettergevoelige naam, interface-GUID en foutcodes |
| Profielinventarisatie | [Microsoft: WlanGetProfileList](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/nf-wlanapi-wlangetprofilelist) | Pointerparameters en vrijgeven van door de API toegewezen geheugen |
| Native layout | [Microsoft: WLAN_INTERFACE_INFO](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ns-wlanapi-wlan_interface_info), [WLAN_PROFILE_INFO](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ns-wlanapi-wlan_profile_info) | GUID, vaste Unicode-buffer en 32-bit status/flags |
| Chrome-opslag | [Chromium: User Data Directory](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/user_data_dir.md) | Standaard Windows-opslag en meerdere profielen; afwijkende kanalen en locaties vallen buiten scope |
| Firefox-opslag | [Mozilla: Profiles](https://support.mozilla.org/en-US/kb/profiles-where-firefox-stores-user-data) | Lokale profielen bevatten onder meer bladwijzers, instellingen en opgeslagen aanmeldingen |
| Omgeleide Edge-opslag | [Microsoft: UserDataDir](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/userdatadir) | Beleid kan de opslaglocatie wijzigen; alleen de standaardlocatie wordt opgeschoond |

## Grenzen

Er zijn geen echte gebruikersgegevens op de ontwikkelcomputer verwijderd. Live browserafsluiting, browserherstart na verwijdering, Wi-Fi-verwijdering en firewallreset zijn niet getest. Nep-browserprofielen controleren bestandverwijdering, niet het gedrag van een echte browser. Niet-standaard browserlocaties, andere gebruikersprofielen en gegevens buiten de geconfigureerde scope worden niet opgeschoond.

Voer de acceptatietest in `SERVICEDESK.md` uit met een wegwerpaccount en de eigen beheerconfiguratie. Een technisch geslaagde uitvoering is geen bewijs dat alle gegevens op het apparaat zijn verwijderd.
