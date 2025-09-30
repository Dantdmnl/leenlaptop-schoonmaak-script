@echo off
setlocal enabledelayedexpansion

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

echo.
echo [INFO] Schoonmaakscript voor leenlaptops wordt gestart...
echo        Script pad: !scriptPath!
echo.

:: Script uitvoeren met RemoteSigned executiebeleid (veiliger dan Bypass)
:: RemoteSigned staat lokale scripts toe maar vereist digitale handtekening voor externe scripts
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "!scriptPath!"

:: Controleer de exit code van het PowerShell script
if %errorlevel% equ 0 (
    echo.
    echo [SUCCES] Scriptuitvoering succesvol voltooid.
    echo.
) else (
    echo.
    echo [WAARSCHUWING] Script voltooid met exit code: %errorlevel%
    echo               Controleer de logbestanden (standaard HiddenScripts folder)voor details.
    echo.
)

echo Druk op een toets om af te sluiten...
pause >nul