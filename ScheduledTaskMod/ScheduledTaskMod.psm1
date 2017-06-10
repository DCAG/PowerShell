<#
    .AUTHOR
    Amir Granot
    .WEBSITE
    http://Granola.tech/
    .DATE
    09 Jun 2017
#>

function Get-ScheduledTaskModWrap
{
    <#
    .SYNOPSIS
    Get a list of scheduled tasks from the local computer or from remote computers
    
    .DESCRIPTION
    Wrapper of schtasks.exe
    
    .PARAMETER ComputerName
    Name of the target computer, default is $env:COMPUTERNAME
    
    .EXAMPLE
    Get-ScheduledTaskModWrap -IncludeComputerName

    .EXAMPLE
    Get-ScheduledTaskModWrap 'TestPC'

    .EXAMPLE
    Write-Output 'TestPC', $env:COMPUTERNAME | Get-ScheduledTaskModWrap

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
        $CSVParams = '/query /V /FO CSV' -split ' '

        if($ComputerName -ne $env:COMPUTERNAME)
        {
            $XMLParams = '/query /S {0} /XML ONE' -f $ComputerName -split ' '
            $CSVParams = '/query /S {0} /V /FO CSV' -f $ComputerName -split ' '
        }
                
        $TasksFromCSV = schtasks.exe $CSVParams 2>&1 | ConvertFrom-Csv
        [xml]$TasksFromXML = schtasks.exe $XMLParams 2>&1

        # Required for 'Author' property - Creator property was in 2008 and earlier, Author replaced Creator property after 2008
        $CSVHeaders = $TasksFromCSV[0].psobject | ForEach-Object Properties | ForEach-Object Name

        $outputFields = 'TaskPath','TaskName','Author','Description','UserID','Command','Arguments','State','URI'
        if($IncludeComputerName)
        {
            $outputFields += @{N='ComputerName'; E={$ComputerName}}
        }

        $TasksFromCSV | Where-Object{$_.Hostname -ne "hostname"} -PipelineVariable task | ForEach-Object {
            $URI      = $task.TaskName 
            $XMLTask  = $TasksFromXML.Tasks | ForEach-Object Task | Where-Object { $_.PreviousSibling.InnerText.Trim() -eq $URI }
            $TaskName = Split-Path $task.TaskName -Leaf
            New-Object -TypeName psobject -Property @{
                TaskPath    = $URI -replace "$TaskName$",''
                TaskName    = $TaskName
                Author      = if($CSVHeaders -contains 'Author'){ $task.Author }else{ $task.Creator }
                Description = $task.Comment
                UserID      = $task.'Run As User'
                Command     = $XMLTask.Actions.Exec.Command
                Arguments   = $XMLTask.Actions.Exec.Arguments
                State       = $task.Status
                URI         = $URI
            }
        } | Select-Object -Property $outputFields -Unique
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
                Write-Warning "All methods of getting the list of scheduled tasks from computer `"$ComputerName`" have failed. You may want to try using this command via Invoke-Command (PowerShell Remoting)"
            }
        }
    } # <END> Process
}

Export-ModuleMember -Function Get-ScheduledTaskMod, Get-ScheduledTaskModWrap