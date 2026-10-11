# Validatie van 1.7.4

Gecontroleerd op 11 oktober 2026.

## Geautomatiseerde controles

- Syntaxcontrole voor PowerShell 5.1, geselecteerde ScriptAnalyzer-regels en compilatie van de C#-helper.
- 90 Pester-tests met tijdelijke testbestanden en gesimuleerde systeemacties: UAC-verzoek en annuleren, veilige doorgifte van het bronpad, accountkeuze, profielinventarisatie, configuratiekeuze op beide locaties, invoercontrole, annuleren, expliciet ConfigPath, migratie, taakvalidatie, gegroepeerd installatieoverzicht, definitieve bevestiging, installatie zonder voorbeeldbestand, herstel na mislukte updates, leeftijdsfilters, links, vergrendeling, status, bewaartermijnen en browseropslag met testprofielen.
- Browserproces-tests simuleren gelijktijdig afsluiten van kindprocessen, opnieuw starten, andere gebruikers, hergebruikte PID's, eigenaarcontrole, tijdslimieten en vergrendelde opslag. De proceshandle-test opent uitsluitend een handle van het eigen testproces; `Stop-Process` is altijd gesimuleerd en stopt geen proces.
- Native WLAN-structuurafmetingen en Unicode-marshaling zonder WLAN-functies aan te roepen.
- Integratietest op een tijdelijke Windows-machine van GitHub: inventarisatie van echte gebruikersprofielen, installatie, geplande taak, taakrechten, NTFS-rechten, snelkoppeling, opdrachtregel, rapportage, configuratiebehoud bij updates en beheer van taaktriggers. Alle opschoonfuncties staan uit. De test weigert uitvoering buiten GitHub Actions.

De integratietest controleert de ingestelde toegangsrechten. De test simuleert geen aanmelding als standaardgebruiker, interactief UAC-venster of fysieke USB-stick. UAC wordt uitsluitend met gesimuleerde procesaanroepen getest. De testmachine draait Windows Server, geen Windows 10/11. Installatie vanaf een USB-stick gebruikt hetzelfde kopieerproces; de fysieke controle staat in de acceptatietest.

## Onderzoeksbronnen

| Onderdeel | Officiele bron | Controle |
| --- | --- | --- |
| Browserprocessen | [Chromium: Multi-process architecture](https://chromium.googlesource.com/website/+/HEAD/site/developers/design-documents/multi-process-architecture/index.md) | Meerdere procesrollen maken een eenmalige PID-lijst onbetrouwbaar tijdens afsluiten; de implementatie inventariseert opnieuw |
| Edge op de achtergrond | [Microsoft: StartupBoostEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled) | Processen kunnen bij aanmelden en na sluiten van het laatste venster op de achtergrond starten; de utility verandert dit beleid niet |
| Firefox-profielvergrendeling | [Mozilla: Firefox already running](https://support.mozilla.org/en-US/kb/firefox-already-running-not-responding) | Achtergebleven processen kunnen profielopslag bezet houden; controleer afsluiten voordat opslag wordt verwijderd |
| Procesidentiteit | [Microsoft: Process Handles and Identifiers](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers), [PROCESS_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-process_information) | PID's kunnen worden hergebruikt; eigenaar en starttijd worden gecontroleerd en de stopactie gebruikt een procesobject met open handle |
| Terugkerende accountgegevens | [Google: Chrome data across devices](https://support.google.com/chrome/answer/165139?hl=en) | Accountgegevens zijn ook op andere aangemelde apparaten beschikbaar; lokale profielverwijdering is geen verwijdering uit een extern account |
| JSON-configuratie | [Microsoft: ConvertFrom-Json (5.1)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-5.1) | Geen JSON-commentaar in PowerShell 5.1; dubbele sleutels gebruiken de laatste waarde. Typevalidatie volgt na het lezen van het expliciet gekozen bestand |
| Automatisch aanmelden | [Microsoft: Logon triggers](https://learn.microsoft.com/en-us/windows/win32/taskschd/starting-an-executable-when-a-user-logs-on), [Principal.LogonType](https://learn.microsoft.com/en-us/windows/win32/taskschd/principal-logontype) | Een gebruikersgebonden aanmeldtrigger staat los van het bestaan van de taak; een interactieve taak vereist een aangemelde gebruiker |
| Administratorrechten | [Microsoft: Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1) | `RunAs` opent UAC; `Wait` en `PassThru` geven het procesresultaat door. Bronpaden worden als letterlijke waarden doorgegeven |
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

Voor 1.7.4 is het gedrag bij draaiende browsers onderzocht. In de oude implementatie kon een kindproces verdwijnen voordat de stopactie daarvoor werd uitgevoerd; die fout brak de browserstap af. De nieuwe procesinventarisatie en herpogingen zijn met gesimuleerde processen getest, niet met echte Chrome-, Edge- of Firefox-processen. Een browser kan na een geslaagde controle alsnog starten; volledige uitsluiting van gelijktijdig gebruik of synchronisatie is geen garantie van de utility.

Voor 1.7.3 zijn JSON-gedrag, UAC (`RunAs`, procesresultaat en argumentdoorgifte) en het onderscheid tussen een geplande taak en aanmeldtrigger opnieuw gecontroleerd in de primaire Microsoft-documentatie. De configuratiekeuze verandert alleen de bron van de instellingen; de installatie blijft expliciete bevestiging en administratorrechten vereisen.

Er zijn geen echte gebruikersgegevens op de ontwikkelcomputer verwijderd. Het afsluiten van echte browsers, opnieuw starten na opschoning, verwijderen van Wi-Fi-profielen en herstellen van de firewall zijn niet getest. Browserprofielen met testgegevens controleren het verwijderen van bestanden, niet het gedrag van een echte browser. Afwijkende browserlocaties, andere gebruikersprofielen en gegevens buiten de ingestelde opschoning worden niet opgeschoond.

Voer de acceptatietest in `SERVICEDESK.md` uit met een tijdelijk testaccount en uw beheerconfiguratie. Een technisch geslaagde uitvoering bewijst niet dat alle gegevens op het apparaat zijn verwijderd.
