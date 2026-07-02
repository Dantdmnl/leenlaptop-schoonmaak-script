# Servicedeskhandleiding - Leenlaptop Schoonmaak Script

**Versie:** 1.6.3
**Doelgroep:** servicedeskmedewerkers en ICT-beheerders
**Laatst bijgewerkt:** 2 juli 2026

## Korte beschrijving

Het script schoont een leenlaptop lokaal op na gebruik. Het verwijdert browserdata, Wi-Fi-profielen, tijdelijke bestanden en oude downloads. Documenten en media-mappen blijven standaard ongemoeid, tenzij ICT deze opties bewust inschakelt.

Het script werkt op de context van de ingelogde gebruiker. Daardoor worden bijvoorbeeld de Downloads-map en `%TEMP%` van die gebruiker opgeschoond, niet die van een beheeraccount.

## Eerste installatie

1. Download of kopieer de bestanden `Install-LeenlaptopSchoonmaak.bat` en `LeenlaptopSchoonmaak.ps1`.
2. Plaats beide bestanden in dezelfde map.
3. Start `Install-LeenlaptopSchoonmaak.bat` met **Als administrator uitvoeren**.
4. Controleer de configuratie die in het venster wordt getoond.
5. Typ `J` om door te gaan.

Controleer na installatie:

- geplande taak: `LeenlaptopSchoonmaak`;
- scriptlocatie: `C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1`;
- logbestand: `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`;
- snelkoppeling: `Leenlaptop Opschonen.lnk`.

## Dagelijks gebruik

Het script draait automatisch wanneer de gebruiker inlogt. Handmatig starten kan via de bureaubladsnelkoppeling of via Taakplanner:

```powershell
Start-ScheduledTask -TaskName "LeenlaptopSchoonmaak"
```

Controleer de laatste status:

```powershell
Get-Content "C:\ProgramData\LeenlaptopSchoonmaak\laatste_status.txt"
```

## Standaardconfiguratie

| Onderdeel | Standaard | Toelichting |
|-----------|-----------|-------------|
| Browser cleanup | Aan | Edge, Chrome en Firefox |
| Wi-Fi cleanup | Aan | Alle profielen verwijderen, tenzij whitelist is gevuld |
| Temp cleanup | Aan | `%TEMP%` van de ingelogde gebruiker |
| Downloads cleanup | Aan | Bestanden ouder dan 7 dagen |
| Documenten cleanup | Uit | Alleen inschakelen na expliciet besluit |
| Afbeeldingen/Video's/Muziek cleanup | Uit | Alleen inschakelen na expliciet besluit |
| Firewall reset | Aan | Vereist administratorrechten |
| Logretentie | 30 dagen | Configureerbaar |

## Logs lezen

Logbestand:

```text
C:\ProgramData\LeenlaptopSchoonmaak\log.txt
```

Voorbeeld:

```text
2026-07-02 09:15:23 [INFO] START opschoning leenlaptop (versie 1.6.3)
2026-07-02 09:15:24 [INFO] Browser gestopt: chrome (poging 1)
2026-07-02 09:15:26 [INFO] Wi-Fi opschoning voltooid: 3 verwijderd, 1 behouden
2026-07-02 09:15:27 [INFO] Temp-bestanden verwijderd (ongeveer 145 items)
2026-07-02 09:15:28 [INFO] Downloads-map opgeschoond: 8 items verwijderd (8 bestanden, 0 lege mappen; ouder dan 7 dagen)
2026-07-02 09:15:30 [INFO] EINDE opschoning - alle taken succesvol voltooid
```

Logniveaus:

| Niveau | Betekenis |
|--------|-----------|
| `INFO` | Normale voortgang |
| `WARN` | Actie is overgeslagen of gedeeltelijk mislukt |
| `ERROR` | Kritieke fout of handmatige controle nodig |

## Veelvoorkomende problemen

### Script draait niet bij inloggen

Controleer:

```powershell
Get-ScheduledTask -TaskName "LeenlaptopSchoonmaak"
Get-ScheduledTaskInfo -TaskName "LeenlaptopSchoonmaak"
```

De taak moet aanwezig zijn en met hoogste rechten draaien. Herinstalleer via `Install-LeenlaptopSchoonmaak.bat` als de taak ontbreekt of verkeerd is ingesteld.

### Wi-Fi-profielen worden niet verwijderd

Waarschijnlijke oorzaak: het script draait zonder administratorrechten. Controleer of de geplande taak is ingesteld op **Met hoogste bevoegdheden uitvoeren**.

### Snelkoppeling staat op het verkeerde bureaublad

Dit kan gebeuren wanneer installatie vanuit een andere beheersessie is uitgevoerd. Log lokaal in als de doelgebruiker en voer de installatie opnieuw uit als administrator, of plaats de snelkoppeling handmatig op het juiste bureaublad.

### Gebruiker mist bestanden

Controleer eerst welke cleanup-opties actief zijn in `LeenlaptopSchoonmaak.ps1`. Standaard worden Documenten en media-mappen niet opgeschoond. Downloads worden standaard alleen opgeschoond voor bestanden ouder dan 7 dagen. Oude mappen worden alleen verwijderd wanneer ze leeg zijn.

Escaleren naar ICT wanneer:

- de gebruiker belangrijke data mist;
- Documenten of media-cleanup is ingeschakeld;
- de log `ERROR`-meldingen bevat;
- de situatie niet uit de configuratie te verklaren is.

### Geen logbestand

Controleer of de map bestaat en schrijfbaar is:

```powershell
Test-Path "C:\ProgramData\LeenlaptopSchoonmaak"
```

Start het script daarna opnieuw als administrator.

## Configuratie aanpassen

Configuratie staat in:

```text
C:\ProgramData\LeenlaptopSchoonmaak\LeenlaptopSchoonmaak.ps1
```

Belangrijke regels:

```powershell
[string[]]$AllowedWiFi = @()
[string[]]$BrowserList = @('msedge','firefox','chrome')

[bool] $EnableDownloadsCleanup = $true
[int]  $DownloadsMaxAgeDays    = 7

[bool] $EnableDocumentsCleanup = $false
[bool] $EnablePicturesCleanup  = $false
[bool] $EnableVideosCleanup    = $false
[bool] $EnableMusicCleanup     = $false
```

Gebruik altijd quotes in arrays:

```powershell
[string[]]$AllowedWiFi = @('kantoor-wifi', 'gast-netwerk')
```

Gebruik `Install-LeenlaptopSchoonmaak.bat` niet opnieuw na lokale maatwerkaanpassingen, tenzij de lokale configuratie opnieuw mag worden overschreven.

## Migratie vanaf oudere versies

Oude versies gebruikten:

- map: `%LOCALAPPDATA%\HiddenScripts`;
- taak: `Opstart-Script`;
- script: `opstart-script.ps1`;
- snelkoppeling: `Terug naar start.lnk` of `Laptop Opschonen.lnk`.

Vanaf 1.6.0 gebruikt het script:

- map: `C:\ProgramData\LeenlaptopSchoonmaak`;
- taak: `LeenlaptopSchoonmaak`;
- script: `LeenlaptopSchoonmaak.ps1`;
- snelkoppeling: `Leenlaptop Opschonen.lnk`.

De migratie wordt automatisch uitgevoerd bij herinstallatie. Oude scriptkopieen worden gebackupt en daarna verwijderd als de nieuwe scriptnaam goed is geplaatst. Als dit niet lukt:

```powershell
Unregister-ScheduledTask -TaskName "Opstart-Script" -Confirm:$false
```

Verwijder daarna oude snelkoppelingen handmatig en draai `Install-LeenlaptopSchoonmaak.bat` opnieuw als administrator.

## Escalatie-informatie

Geef bij escalatie minimaal mee:

- `C:\ProgramData\LeenlaptopSchoonmaak\log.txt`;
- `C:\ProgramData\LeenlaptopSchoonmaak\laatste_status.txt`;
- Windows-versie en computernaam;
- omschrijving van de handeling die fout ging;
- eventuele screenshot van de foutmelding.

## Checklist nieuwe leenlaptop

- [ ] Windows-updates uitgevoerd.
- [ ] Beveiligingssoftware actief.
- [ ] Lokale beheeraccount beschikbaar.
- [ ] `Install-LeenlaptopSchoonmaak.bat` uitgevoerd als administrator.
- [ ] Geplande taak `LeenlaptopSchoonmaak` gecontroleerd.
- [ ] Snelkoppeling gecontroleerd.
- [ ] Testrun uitgevoerd.
- [ ] `laatste_status.txt` gecontroleerd.
- [ ] Gebruiker geinformeerd over automatische opschoning.
