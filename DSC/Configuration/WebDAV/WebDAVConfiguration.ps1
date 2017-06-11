<#
    .AUTHOR
    Amir Granot
    .WEBSITE
    http://Granola.tech/
    .DATE
    09 Jun 2017
#>
Configuration WebDAV
{
    # Import the module that defines custom resources
    Import-DscResource -Module xWebAdministration, PSDesiredStateConfiguration

    Node $AllNodes.where{$_.Role -eq 'WebDAV'}.NodeName
    {   
    
        <#####################
            WebDAV Server
        #####################>     
        WindowsFeature IISRole
        {
            Name = 'Web-Server'
        }
        
        @('Web-DAV-Publishing','Web-Url-Auth','Web-Mgmt-Tools',
        'Web-Scripting-Tools','Web-Windows-Auth','Web-Http-Redirect') | ForEach-Object{
            WindowsFeature $_
            {
                Name = $_
                DependsOn = '[WindowsFeature]IISRole'
            }
        }
             
        Script WebDAVInApplicationHost
        {
            GetScript = "@{}" <#{
                $Results = @{
                     = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location 'Default Web Site' -Filter 'system.webServer/webdav/authoring' -Name 'enabled' | % Value
                }

                $Results
            }#>

            SetScript = {
                Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location 'Default Web Site' -Filter 'system.webServer/webdav/authoring' -Name 'enabled' -Value 'True'
            }

            TestScript = {
                Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location 'Default Web Site' -Filter 'system.webServer/webdav/authoring' -Name 'enabled' | Select-Object -ExpandProperty Value -First 1 -Unique
            }

            DependsOn = '[WindowsFeature]IISRole','[WindowsFeature]Web-DAV-Publishing','[WindowsFeature]Web-Scripting-Tools'
        }

        <#
        xSSLSettings WebDAVCert
        {
            Bindings = 'Ssl'
            Name = [string]
            DependsOn = 'WebDAV'
            #[Ensure = [string]{ Absent | Present }]
            #[PsDscRunAsCredential = [PSCredential]]
        }
        #>

        <#####################
            WebDAV Web Apps
        ######################>
        foreach($webApp in $Node.WebApps)
        {
            File "Directory$($webApp.AppName)"
            {
                DestinationPath = $webApp.AppFolder
                Type            = 'Directory'
                DependsOn       = '[WindowsFeature]IISRole'
            }

            xWebApplication "WebApp$($webApp.AppName)"
            {
                Website = 'Default Web Site'
                Name = $webApp.AppName
                PhysicalPath = $webApp.AppFolder
                WebAppPool = 'DefaultAppPool'
                AuthenticationInfo = `
                MSFT_xWebApplicationAuthenticationInformation
                {
                    Anonymous = $false
                    Basic     = $false
                    Digest    = $false
                    Windows   = $true
                }
                DependsOn = '[WindowsFeature]Web-Windows-Auth',"[File]Directory$($webApp.AppName)"
            }

            Script "WebDAVAuthoringRule$($webApp.AppName)"
            {
                GetScript = {
                    Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "Default Web Site/$($using:webApp.AppName)" -Filter 'system.webServer/webdav/authoringRules/add' -Name '.' | Select-Object users,roles,path,access
                    return @{
                        'Result' = '' 
                    }
                }

                SetScript = {
                    Remove-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "Default Web Site/$($using:webApp.AppName)" -Filter 'system.webServer/webdav/authoringRules/add' -Name '.'
                    $using:webApp.WebDAVAuthoringRules | ForEach-Object{
                        Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "Default Web Site/$($using:webApp.AppName)" -Filter 'system.webServer/webdav/authoringRules' -Name '.' -Value $_

                    }
                }

                TestScript = {
                    $CompareAuthoringRules = @{
                        ReferenceObject  = $using:webApp.WebDAVAuthoringRules | ForEach-Object{ [pscustomobject]$_ }
                        DifferenceObject = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location "Default Web Site/$($using:webApp.AppName)" -Filter 'system.webServer/webdav/authoringRules/add' -Name '.' | Select-Object users,roles,path,access
                    }

                    if($CompareAuthoringRules.ReferenceObject -eq $null -and $CompareAuthoringRules.DifferenceObject -eq $null)
                    {
                        $true
                    }
                    elseif($CompareAuthoringRules.ReferenceObject -eq $null -or $CompareAuthoringRules.DifferenceObject -eq $null)
                    {
                        $false
                    }
                    else{
                        (Compare-Object @CompareAuthoringRules) -eq $null
                    }
                }

                DependsOn = '[WindowsFeature]IISRole','[WindowsFeature]Web-DAV-Publishing','[WindowsFeature]Web-Scripting-Tools','[Script]WebDAVInapplicationHost'
            }
        }
    }
}


$ConfFolder = 'P:\Workspace\Builds\PowerShell.DSC.Configuration.WebDAV'

WebDAV -ConfigurationData "$PSScriptRoot\WebDAVConfiguration.psd1" -OutputPath $ConfFolder -Verbose

# uncomment when needed
#Start-DscConfiguration -Path $ConfFolder -Wait -Force -Verbose

#Test-DscConfiguration $ConfFolder -Verbose | Format-List * -Force