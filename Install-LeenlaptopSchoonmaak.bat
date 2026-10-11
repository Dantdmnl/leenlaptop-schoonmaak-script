@echo off
setlocal
title Leenlaptop Schoonmaak - installatie
echo Leenlaptop Schoonmaak 1.7.1
echo Installatie verwijdert geen gebruikersgegevens.
echo.
if not exist "%~dp0LeenlaptopSchoonmaak.psm1" (
    echo Module ontbreekt. Pak het volledige releasearchief uit.
    pause
    exit /b 1
)
set "LEENLAPTOP_SCRIPT=%~dp0LeenlaptopSchoonmaak.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& $env:LEENLAPTOP_SCRIPT -Install -Interactive; exit $LASTEXITCODE"
set "result=%errorlevel%"
echo.
echo Installatie afgesloten met code %result%.
pause
exit /b %result%
