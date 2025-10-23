@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Initial Setup Script voor Leenlaptop Opschoningsscript
:: Versie: 1.5.0
:: Datum: 2025-10-23
:: Doel: Eenvoudige en betrouwbare installatie vanaf USB-stick
:: ============================================================================

title Leenlaptop Opschoningsscript - Installatie

echo.
echo ========================================================================
echo  LEENLAPTOP OPSCHONINGSSCRIPT - INSTALLATIE
echo ========================================================================
echo  Versie: 1.5.0
echo  AVG-conform ^| Ontwerp-compliant
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
if not defined PS_HiddenFolderName set "PS_HiddenFolderName=HiddenScripts"
if not defined PS_ScriptVersion set "PS_ScriptVersion=1.5.0"
if not defined PS_EnableStartupTask set "PS_EnableStartupTask=true"
if not defined PS_EnableShortcut set "PS_EnableShortcut=true"
if not defined PS_EnableFirewallReset set "PS_EnableFirewallReset=true"
if not defined PS_MaxExecutionMinutes set "PS_MaxExecutionMinutes=5"
if not defined PS_LogRetentionDays set "PS_LogRetentionDays=30"
if not defined PS_TaskName set "PS_TaskName=Opstart-Script"

set "targetHidden=%LOCALAPPDATA%\%PS_HiddenFolderName%"

echo.
echo        Gedetecteerde configuratie:
echo        - Versie: %PS_ScriptVersion%
echo        - Doellocatie: %targetHidden%
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
if /i "%PS_EnableFirewallReset%"=="true" (
    echo        - Firewall resetten: AAN
) else (
    echo        - Firewall resetten: UIT
)
if defined PS_BrowserList echo        - Browsers: %PS_BrowserList%
if defined PS_AllowedWiFi echo        - Wi-Fi whitelist: %PS_AllowedWiFi%
echo        - Logretentie: %PS_LogRetentionDays% dagen
echo        - Max uitvoering: %PS_MaxExecutionMinutes% minuten
echo.
echo ========================================================================
echo.

:: Bevestiging voor installatie met bovenstaande configuratie
set /p "proceed=Doorgaan met installatie met deze configuratie? (J/N): "
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
