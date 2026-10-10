#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 3.4.0 -MaximumVersion 4.99.99 -ErrorAction Stop
$result = Invoke-Pester -Script (Join-Path $PSScriptRoot 'LeenlaptopSchoonmaak.Tests.ps1') -PassThru
if ($result.FailedCount -gt 0) { exit 1 }
if ($result.TotalCount -eq 0) { throw 'Geen tests uitgevoerd.' }
