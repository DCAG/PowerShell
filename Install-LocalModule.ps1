#Requires -RunAsAdministrator
#Requires -Version 5
[CmdletBinding()]
param(
    [ValidateScript({(Test-Path $_ -PathType Container) -and (Get-ChildItem $_\*.psd1)})]
    [string]$Path)

$moduleFolder   = (Get-Item -Path $Path).FullName
$moduleName     = Split-Path $moduleFolder.FullName -Leaf
$moduleManifest = Import-PowerShellDataFile $moduleFolder\$moduleName.psd1 -Verbose
Write-Verbose "Module `"$moduleName`" version is $($moduleManifest.ModuleVersion)"

mkdir "$env:ProgramFiles\WindowsPowerShell\Modules\$moduleName\$($moduleManifest.ModuleVersion)" -Force
Copy-Item $moduleFolder\* -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\$moduleName\$($moduleManifest.ModuleVersion)\" -Force -Verbose