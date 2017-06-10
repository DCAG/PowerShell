#Requires -RunAsAdministrator
#Requires -Version 5
[CmdletBinding()]
param(
    [ValidateScript({(Test-Path $_ -PathType Container) -and (Get-ChildItem $_\*.psd1)})]
    [string]$Path)

$moduleFolder   = Resolve-Path $Path
$moduleName     = Split-Path $moduleFolder -Leaf
$moduleManifest = Import-PowerShellDataFile $moduleFolder\$moduleName.psd1 # Import-PowerShellDataFile (PowerShell version 5)

Write-Verbose "Module `"$moduleName`" version is $($moduleManifest.ModuleVersion)"

mkdir "$env:ProgramFiles\WindowsPowerShell\Modules\$moduleName\$($moduleManifest.ModuleVersion)" -Force
Copy-Item $moduleFolder\* -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\$moduleName\$($moduleManifest.ModuleVersion)\" -Force -Verbose:($PSBoundParameters.Verbose -eq $true)