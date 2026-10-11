@echo off
setlocal
title Leenlaptop Schoonmaak - installatie
echo Leenlaptop Schoonmaak 1.7.2
echo Installatie verwijdert geen gebruikersgegevens.
echo.
if not exist "%~dp0LeenlaptopSchoonmaak.psm1" (
    echo Module ontbreekt. Pak het volledige releasearchief uit.
    pause
    exit /b 1
)
set "LEENLAPTOP_SOURCE=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Import-Module (Join-Path $env:LEENLAPTOP_SOURCE 'LeenlaptopSchoonmaak.psm1') -Force -ErrorAction Stop; $code = Invoke-LeenlaptopInstaller -SourcePath $env:LEENLAPTOP_SOURCE; exit $code } catch { Write-Host ('Installatie gestopt: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"
set "result=%errorlevel%"
echo.
echo Installatie afgesloten met code %result%.
pause
exit /b %result%
