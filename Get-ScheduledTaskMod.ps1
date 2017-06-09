<#
    .AUTHOR
    Amir Granot
    .WEBSITE
    http://Granola.tech/
    .DATE
    09 Jun 2017
#>

function Get-ScheduledTaskModCSV
{
    <#
    .SYNOPSIS
    Get a list of scheduled tasks from the local machine or from remote computers
    
    .DESCRIPTION
    Wrapper of schtasks.exe using the CSV export format option to create PSObjects representation of scheduled tasks.
    More detailed than Get-ScheduledTaskModXML.
    
    .PARAMETER ComputerName
    Name of the target computer, default is $env:COMPUTERNAME
    
    .EXAMPLE
    Get-ScheduledTaskModCSV -IncludeComputerName

    .EXAMPLE
    Get-ScheduledTaskModCSV 'TestPC'

    .EXAMPLE
    Write-Output 'TestPC', $env:COMPUTERNAME | Get-ScheduledTaskModCSV

    .NOTES
    
    #>
    [CmdletBinding()]
    param(
    [Alias('__Server','DNSHostName','IPAddress','Computer','Server')]
    [parameter(ValueFromPipeline=$true)]
    [ValidatePattern('^[^\s]*$')]
    [string]$ComputerName = $env:COMPUTERNAME,
    [switch]$IncludeComputerName)
    
    Begin{
        if($PSCmdlet.MyInvocation.PipelinePosition -gt 1)
        {
            $IncludeComputerName = $true
        }

        $tempFilePath = Join-Path -Path $env:Temp -ChildPath 'schtasks.csv'
    }

    Process{
        if($ComputerName -eq $env:COMPUTERNAME)
        {
            $schtasksParams = '/query /V /FO CSV' -split ' '
        }
        else
        {
            $schtasksParams = '/query /S {0} /V /FO CSV' -f $ComputerName -split ' '
        }
                
        schtasks.exe $schtasksParams 2>&1 | Out-File $tempFilePath -Encoding utf8 -Force

        if(-not (test-path $tempFilePath)){
            throw ('Unable to find {0}' -f $tempFilePath)
        }

        $fields = @(
            @{N='TaskPath';E={$parent = Split-Path $_.TaskName -Parent; if($parent -ne '\'){$parent + '\'}else{'\'}}},
            @{N='TaskName';E={Split-Path $_.TaskName -Leaf}},
            @{N='Author'     ; E={
                    $fields = $_.psobject.Properties | ForEach-Object Name
                    if($fields -contains "Author"){ $_.Author }else{ $_.Creator }
                }
            },
            @{N='Description'; E={$_.Comment}},
            @{N='UserID'     ; E={$_.'Run As User'}},
            @{N='Command'    ; E={$_.'Task To Run'}},
            'Arguments',
            @{N='State'      ;E={$_.Status}},
            @{N='URI'        ;E={$_.TaskName}}        
        )

        if($IncludeComputerName)
        {
            $fields += @{N='ComputerName'; E={$ComputerName}}
        }

        Import-Csv $tempFilePath | Where-Object{$_.Hostname -ne "hostname"} | Select-Object -Property $fields -Unique

        # Cleanup
        Remove-Item -Path $tempFilePath -ErrorAction SilentlyContinue -Force
    } # <END> Process
}

function Get-ScheduledTaskModXML
{
    <#
    .SYNOPSIS
    Get a list of scheduled tasks from the local machine or from remote computers
    
    .DESCRIPTION
    Wrapper of schtasks.exe using the XML export format option to create PSObjects representation of scheduled tasks
    
    .PARAMETER ComputerName
    Name of the target computer, default is $env:COMPUTERNAME

    .EXAMPLE
    Get-ScheduledTaskModXML -IncludeComputerName

    .EXAMPLE
    Get-ScheduledTaskModXML 'TestPC'

    .EXAMPLE
    Write-Output 'TestPC', $env:COMPUTERNAME | Get-ScheduledTaskModXML
    
    .NOTES

    #>
    [CmdletBinding()]
    param(
    [Alias('__Server','DNSHostName','IPAddress','Computer','Server')]
    [parameter(ValueFromPipeline=$true)]
    [ValidatePattern('^[^\s]*$')]
    [string]$ComputerName = $env:COMPUTERNAME,
    [switch]$IncludeComputerName)

    Begin{
        if($PSCmdlet.MyInvocation.PipelinePosition -gt 1)
        {
            $IncludeComputerName = $true
        }
    }

    Process{
        $XMLParams = '/query /XML ONE' -split ' '
        $CSVParams = '/query /fo CSV' -split ' '

        if($ComputerName -ne $env:COMPUTERNAME)
        {
            $XMLParams = '/query /S {0} /XML ONE' -f $ComputerName -split ' '
            $CSVParams = '/query /S {0} /fo CSV' -f $ComputerName -split ' '
        }
        
        $Tasks = schtasks.exe $XMLParams 2>&1
        $CSVTasks = schtasks.exe $CSVParams 2>&1 | select-string -NotMatch '"TaskName","Next Run Time","Status"'
        $TasksStatuses = [System.Collections.ArrayList]@('"TaskName","Next Run Time","Status"')+[System.Collections.ArrayList]$CSVTasks
        $StatusList = $TasksStatuses | convertfrom-csv
        foreach ($Task in ([xml]$Tasks).Tasks.Task)
        {
            $fields = 'TaskPath','TaskName','Author','Description','UserID','Command','Arguments','State','URI'
            if($IncludeComputerName)
            {
                $fields += @{N='ComputerName'; E={$ComputerName}}
            }

            $URI = $Task.PreviousSibling.InnerText.Trim()
            $TaskName = Split-Path $URI -Leaf
            New-Object -TypeName psobject -Property @{
                TaskPath    = $URI -replace "$TaskName$",''
                TaskName    = $TaskName
                Author      = $Task.RegistrationInfo.Author
                Description = $Task.RegistrationInfo.Description
                UserID      = $Task.Principals.Principal.UserId
                Command     = $Task.Actions.Exec.Command
                Arguments   = $Task.Actions.Exec.Arguments
                State       = $StatusList | Where-Object {$_.TaskName -eq $URI} | Select-Object -ExpandProperty 'Status' -Unique
                URI         = $URI
            } | Select-Object -Property $fields 
        }
    } # <END> Process
}

function Get-ScheduledTaskMod
{
    <#
    .SYNOPSIS
    Get Scheduled Tasks.
    Able to query the local computer or remote computers.
    
    .DESCRIPTION
    Get-ScheduledTaskMod is a replacement for the command Get-ScheduledTask
    that doesn't exist for Operating Systems Windows 7 and earlier
    and doesn't have a built-in ability to query remote computers.

    This cmdlet first tries to call Get-ScheduledTask, but if it doesn't exist or there is a request to query remote computer
    a wrapper for schtasks.exe is called.
    
    .PARAMETER ComputerName
    Name of the target computer, default is $env:COMPUTERNAME
    
    .EXAMPLE
    Get-ScheduledTaskMod 'TestPC'

    .EXAMPLE
    Write-Output 'TestPC', $env:COMPUTERNAME | Get-ScheduledTaskMod
    
    .NOTES

    #>
    [CmdletBinding()]
    param(
    [Alias('__Server','DNSHostName','IPAddress','Computer','Server')]
    [parameter(ValueFromPipeline=$true)]
    [ValidatePattern('^[^\s]*$')]
    [string]$ComputerName = $env:COMPUTERNAME)
    
    Begin{
        if($PSCmdlet.MyInvocation.PipelinePosition -gt 1)
        {
            $IncludeComputerName = $true
        }
    }

    Process {
        if(($ComputerName -eq $env:COMPUTERNAME) -and (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)){ #the command may not exist in previous powershell versions
            
            $fields = 'TaskPath','TaskName','Author','Description',@{N='UserID';E={$_.Principal.UserId}},@{N='Command';E={$_.Actions | select-object -ExpandProperty 'Execute' -ErrorAction SilentlyContinue}},@{N='Arguments';E={$_.Actions | select-object -ExpandProperty 'Arguments' -ErrorAction SilentlyContinue}},'State','URI'
            if($IncludeComputerName)
            {
                $fields += @{N='ComputerName'; E={$ComputerName}}
            }

            Get-ScheduledTask -Verbose | Select-Object -Property $fields
        }
        else
        {
            try{
                Write-Verbose "Invoking Get-ScheduledTaskModCSV"
                Get-ScheduledTaskModCSV -ComputerName $ComputerName -IncludeComputerName:$IncludeComputerName -ErrorAction Stop
            }
            catch{
                Write-Warning $_.Exception.Message
                try{
                    Write-Verbose "Invoking Get-ScheduledTaskModXML"
                    Get-ScheduledTaskModXML -ComputerName $ComputerName -IncludeComputerName:$IncludeComputerName -ErrorAction Stop
                }
                catch{
                    Write-Warning $_.Exception.Message                
                    Write-Warning "All methods of getting the list of scheduled tasks from computer `"$ComputerName`" have failed. You may want to try using this command via Invoke-Command (PowerShell Remoting)"
                }
            }
        }
    } # <END> Process
}

#Export-ModuleMember -Function Get-ScheduledTaskMod, Get-ScheduledTaskModCSV, Get-ScheduledTaskModXML

#(Get-ScheduledTaskModXML)+(Get-ScheduledTaskModCSV)+(Get-ScheduledTaskMod) | ogv