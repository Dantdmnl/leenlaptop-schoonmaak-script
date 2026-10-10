@echo off
setlocal
title Leenlaptop Schoonmaak - installatie
echo Leenlaptop Schoonmaak 1.7.0-rc.1
echo Installatie verwijdert geen gebruikersgegevens.
echo.
if not exist "%~dp0LeenlaptopSchoonmaak.psm1" (
    echo Module ontbreekt. Pak het volledige releasearchief uit.
    pause
    exit /b 1
)
set /p "targetUser=Doelaccount (bijvoorbeeld LAPTOP\leenaccount): "
if not defined targetUser exit /b 1
set /p "proceed=Installeren voor dit account? (J/N): "
if /i not "%proceed%"=="J" exit /b 0
set "LEENLAPTOP_TARGET_USER=%targetUser%"
set "LEENLAPTOP_SCRIPT=%~dp0LeenlaptopSchoonmaak.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& $env:LEENLAPTOP_SCRIPT -Install -TargetUser $env:LEENLAPTOP_TARGET_USER; exit $LASTEXITCODE"
set "result=%errorlevel%"
echo.
echo Installatie afgesloten met code %result%.
pause
exit /b %result%
