#requires -Version 5.1
<#
.SYNOPSIS
Controleert, installeert of gebruikt Leenlaptop Schoonmaak.
.DESCRIPTION
Zonder actie wordt alleen de configuratie gecontroleerd. Opschoning vereist -Cleanup.
-WhatIf toont de geplande stappen zonder bestanden, processen of instellingen te wijzigen.
.EXAMPLE
.\LeenlaptopSchoonmaak.ps1 -Install -TargetUser 'LAPTOP\leenaccount'
.EXAMPLE
.\LeenlaptopSchoonmaak.ps1 -Cleanup -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ParameterSetName = 'Install', Mandatory)][switch]$Install,
    [Parameter(ParameterSetName = 'Cleanup', Mandatory)][switch]$Cleanup,
    [Parameter(ParameterSetName = 'Check')][switch]$Check,
    [Parameter(ParameterSetName = 'Config', Mandatory)][switch]$PrintConfig,
    [Parameter(ParameterSetName = 'Install')][string]$TargetUser,
    [Parameter(ParameterSetName = 'Install')][switch]$Interactive,
    [string]$ConfigPath,
    [string]$InstallPath = "$env:ProgramData\LeenlaptopSchoonmaak"
)

$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'LeenlaptopSchoonmaak.psm1') -Force
    $action = 'Check'
    if ($Install) { $action = 'Install' }
    if ($Cleanup) { $action = 'Cleanup' }
    if ($PrintConfig) { $action = 'Config' }
    $arguments = @{
        Action = $action; SourcePath = $PSScriptRoot; InstallPath = $InstallPath
        ConfigPath = $ConfigPath; TargetUser = $TargetUser; Interactive = $Interactive
    }
    if ($WhatIfPreference) { $arguments.WhatIf = $true }
    if ($PSBoundParameters.ContainsKey('Confirm')) { $arguments.Confirm = $PSBoundParameters.Confirm }
    $result = Invoke-LeenlaptopUtility @arguments
    if ($action -eq 'Config') { $result.Config | ConvertTo-Json -Depth 5 }
    else {
        $result | Format-List Version, Action, Status, ConfigSource
        $result.Results | Format-Table Name, Status, Removed, Failed, Detail -Wrap
    }
    exit $result.ExitCode
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
