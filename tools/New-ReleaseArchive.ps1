#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputPath)
$ErrorActionPreference = 'Stop'
if (-not $OutputPath) { $OutputPath = Join-Path $PSScriptRoot '..\dist' }
$root = Split-Path $PSScriptRoot
$files = @('LeenlaptopSchoonmaak.ps1', 'LeenlaptopSchoonmaak.psm1', 'WlanProfiles.cs',
    'Install-LeenlaptopSchoonmaak.bat', 'config.example.json', 'README.md', 'SERVICEDESK.md', 'AVG-COMPLIANCE.md', 'CHANGELOG.md', 'VALIDATION.md')
$paths = @($files | ForEach-Object {
    $path = Join-Path $root $_
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Releasebestand ontbreekt: $_" }
    $path
})
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
$archive = Join-Path $OutputPath 'LeenlaptopSchoonmaak-1.7.0.zip'
Compress-Archive -LiteralPath $paths -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
'{0}  {1}' -f $hash, (Split-Path $archive -Leaf) | Set-Content -LiteralPath (Join-Path $OutputPath 'SHA256SUMS.txt') -Encoding ASCII
Get-Item -LiteralPath $archive
