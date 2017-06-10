<#
    .AUTHOR
    Amir Granot
    .WEBSITE
    http://Granola.tech/
    .DATE
    09 Jun 2017
#>
[DscLocalConfigurationManager()]
Configuration LCMConfig
{
    Node $AllNodes.where{$_.Role -eq 'WebDAV'}.NodeName
    {
        Settings
        {
           RebootNodeIfNeeded = $true
           RefreshMode = 'Push'
           ConfigurationMode = 'ApplyOnly'
           ActionAfterReboot = 'ContinueConfiguration'
        }
    }
}

$ConfFolder = 'P:\Workspace\Builds\PowerShell.DSC.Configuration.WebDAV'

LCMConfig -ConfigurationData "$PSScriptRoot\WebDAVConfiguration.psd1" -OutputPath $ConfFolder

Set-DscLocalConfigurationManager -Path $ConfFolder -Verbose