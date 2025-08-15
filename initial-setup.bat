@echo off
:: Controleer op adminrechten
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Dit script moet als administrator worden uitgevoerd.
    pause
    exit /b
)

:: PowerShell-executiebeleid tijdelijk aanpassen
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0opstart-script.ps1"

:: Script uitvoeren
set "scriptPath=%~dp0opstart-script.ps1"
if exist "%scriptPath%" (
    echo Script wordt uitgevoerd...
    powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%scriptPath%"
    echo Scriptuitvoering voltooid.
    pause
) else (
    echo Script niet gevonden op: %scriptPath%
    pause
)

pause