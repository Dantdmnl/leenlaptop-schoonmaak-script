@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Initial Setup Script voor Leenlaptop Opschoningsscript
:: Versie: 1.6.0
:: Datum: 2025-11-03
:: Doel: Eenvoudige en betrouwbare installatie vanaf USB-stick
:: ============================================================================

title Leenlaptop Opschoningsscript - Installatie

echo.
echo ========================================================================
echo  LEENLAPTOP OPSCHONINGSSCRIPT - INSTALLATIE
echo ========================================================================
echo  Versie: 1.6.0
echo  AVG-conform ^| Volledig configureerbaar
echo ========================================================================
echo.

:: Controleer op adminrechten
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [FOUT] Dit script moet als administrator worden uitgevoerd.
    echo        Klik met de rechtermuisknop op het bestand en kies "Als administrator uitvoeren"
    echo.
    pause
    exit /b 1
)

:: Definieer het PowerShell script pad
set "scriptPath=%~dp0opstart-script.ps1"

:: Controleer of het PowerShell script bestaat
if not exist "!scriptPath!" (
    echo.
    echo [FOUT] PowerShell script niet gevonden op: !scriptPath!
    echo        Controleer of beide bestanden in dezelfde map staan.
    echo.
    pause
    exit /b 1
)

:: Controleer PowerShell beschikbaarheid
powershell.exe -Command "Write-Host 'PowerShell test'" >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [FOUT] PowerShell is niet beschikbaar of toegankelijk.
    echo.
    pause
    exit /b 1
)

echo [INFO] Schoonmaakscript voor leenlaptops wordt gestart...
echo        Script pad: !scriptPath!

:: Lees configuratie dynamisch uit het PowerShell script (geen extra bestanden nodig)
for /f "delims=" %%i in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!scriptPath!" -PrintConfig') do %%i

:: Fallbacks indien variabelen niet gelezen konden worden
if not defined PS_HiddenFolderName set "PS_HiddenFolderName=LeenlaptopSchoonmaak"
if not defined PS_ScriptVersion set "PS_ScriptVersion=1.6.0"
if not defined PS_TaskName set "PS_TaskName=LeenlaptopSchoonmaak"
if not defined PS_EnableStartupTask set "PS_EnableStartupTask=true"
if not defined PS_EnableShortcut set "PS_EnableShortcut=true"
if not defined PS_EnableBrowserCleanup set "PS_EnableBrowserCleanup=true"
if not defined PS_EnableWiFiCleanup set "PS_EnableWiFiCleanup=true"
if not defined PS_EnableTempCleanup set "PS_EnableTempCleanup=true"
if not defined PS_EnableDownloadsCleanup set "PS_EnableDownloadsCleanup=true"
if not defined PS_DownloadsMaxAgeDays set "PS_DownloadsMaxAgeDays=7"
if not defined PS_EnableDocumentsCleanup set "PS_EnableDocumentsCleanup=false"
if not defined PS_DocumentsMaxAgeDays set "PS_DocumentsMaxAgeDays=30"
if not defined PS_EnablePicturesCleanup set "PS_EnablePicturesCleanup=false"
if not defined PS_PicturesMaxAgeDays set "PS_PicturesMaxAgeDays=30"
if not defined PS_EnableVideosCleanup set "PS_EnableVideosCleanup=false"
if not defined PS_VideosMaxAgeDays set "PS_VideosMaxAgeDays=30"
if not defined PS_EnableMusicCleanup set "PS_EnableMusicCleanup=false"
if not defined PS_MusicMaxAgeDays set "PS_MusicMaxAgeDays=30"
if not defined PS_EnableFirewallReset set "PS_EnableFirewallReset=true"
if not defined PS_EnableBackupCleanup set "PS_EnableBackupCleanup=true"
if not defined PS_MaxExecutionMinutes set "PS_MaxExecutionMinutes=5"
if not defined PS_LogRetentionDays set "PS_LogRetentionDays=30"

set "targetHidden=C:\ProgramData\%PS_HiddenFolderName%"

echo.
echo        Gedetecteerde configuratie:
echo        - Versie: %PS_ScriptVersion%
echo        - Doellocatie: %targetHidden%
echo.
echo        VOORZIENINGEN:
if /i "%PS_EnableStartupTask%"=="true" (
    echo        - Geplande taak: AAN ^(TaskName: %PS_TaskName%^)
) else (
    echo        - Geplande taak: UIT
)
if /i "%PS_EnableShortcut%"=="true" (
    echo        - Bureaubladsnelkoppeling: AAN
) else (
    echo        - Bureaubladsnelkoppeling: UIT
)
echo.
echo        OPSCHONING:
if /i "%PS_EnableBrowserCleanup%"=="true" (
    if defined PS_BrowserList (
        echo        - Browser opschoning: AAN ^(%PS_BrowserList%^)
    ) else (
        echo        - Browser opschoning: AAN ^(geen browsers geconfigureerd^)
    )
) else (
    echo        - Browser opschoning: UIT
)
if /i "%PS_EnableWiFiCleanup%"=="true" (
    if defined PS_AllowedWiFi (
        echo        - Wi-Fi profielen: AAN ^(whitelist: %PS_AllowedWiFi%^)
    ) else (
        echo        - Wi-Fi profielen: AAN ^(alle profielen verwijderen^)
    )
) else (
    echo        - Wi-Fi profielen: UIT
)
if /i "%PS_EnableTempCleanup%"=="true" (
    echo        - Temp-bestanden: AAN
) else (
    echo        - Temp-bestanden: UIT
)
if /i "%PS_EnableDownloadsCleanup%"=="true" (
    echo        - Downloads opschonen: AAN ^(^>%PS_DownloadsMaxAgeDays% dagen^)
) else (
    echo        - Downloads opschonen: UIT
)
if /i "%PS_EnableDocumentsCleanup%"=="true" (
    echo        - Documenten opschonen: AAN ^(^>%PS_DocumentsMaxAgeDays% dagen - WAARSCHUWING!^)
) else (
    echo        - Documenten opschonen: UIT
)
if /i "%PS_EnablePicturesCleanup%"=="true" (
    echo        - Afbeeldingen opschonen: AAN ^(^>%PS_PicturesMaxAgeDays% dagen - WAARSCHUWING!^)
) else (
    echo        - Afbeeldingen opschonen: UIT
)
if /i "%PS_EnableVideosCleanup%"=="true" (
    echo        - Video's opschonen: AAN ^(^>%PS_VideosMaxAgeDays% dagen - WAARSCHUWING!^)
) else (
    echo        - Video's opschonen: UIT
)
if /i "%PS_EnableMusicCleanup%"=="true" (
    echo        - Muziek opschonen: AAN ^(^>%PS_MusicMaxAgeDays% dagen - WAARSCHUWING!^)
) else (
    echo        - Muziek opschonen: UIT
)
if /i "%PS_EnableFirewallReset%"=="true" (
    echo        - Firewall resetten: AAN
) else (
    echo        - Firewall resetten: UIT
)
if /i "%PS_EnableBackupCleanup%"=="true" (
    echo        - Oude backups opruimen: AAN
) else (
    echo        - Oude backups opruimen: UIT
)
echo.
echo        RETENTIE:
echo        - Logretentie: %PS_LogRetentionDays% dagen
echo        - Max uitvoering: %PS_MaxExecutionMinutes% minuten
echo.
echo ========================================================================
echo.

:: Bevestiging voor installatie
set /p "proceed=Wilt u doorgaan met de installatie? (J/N): "
if /i not "%proceed%"=="J" (
    echo.
    echo [i] Installatie geannuleerd door gebruiker.
    echo.
    echo Druk op een toets om af te sluiten...
    pause >nul
    exit /b 0
)

:: Script uitvoeren met Bypass executiebeleid
:: Bypass is nodig omdat RemoteSigned kan falen op systemen met Restricted policy
:: Dit is veilig omdat we een lokaal script uitvoeren dat de gebruiker zelf heeft gestart
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "!scriptPath!"

:: Controleer de exit code van het PowerShell script
if %errorlevel% equ 0 (
    echo.
    echo ========================================================================
    echo  [SUCCES] Installatie succesvol voltooid!
    echo ========================================================================
    echo.
    echo  Het script is geinstalleerd en de USB-stick mag nu worden verwijderd.
    echo.
    echo  Logbestanden: %targetHidden%\
    echo.
) else (
    echo.
    echo ========================================================================
    echo  [WAARSCHUWING] Script voltooid met exit code: %errorlevel%
    echo ========================================================================
    echo.
    echo  De installatie is mogelijk niet volledig geslaagd.
    echo  Controleer de logbestanden in: %targetHidden%\
    echo.
)

echo Druk op een toets om af te sluiten...
pause >nul
