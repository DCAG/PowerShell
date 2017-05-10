function Get-ScheduledTaskModCSVSMB
{
    [CmdletBinding()]
    param(
    [Alias('__Server','DNSHostName','IPAddress','Computer','Server')]
    [string]$ComputerName = $env:COMPUTERNAME)
        
    $tempfile = 'taskslist.csv'
    $tempfolder = 'C:\temp'
    if($ComputerName -eq $env:COMPUTERNAME)
    {
        $schtasksParams = '/query /V /FO CSV'
    }
    else
    {
        $schtasksParams = '/query /S {0} /V /FO CSV' -f $ComputerName
    }
    if(-not(test-path $tempfolder -PathType Container))
    {
        New-Item -Path $tempfolder -ItemType Directory
    }
              
    invoke-expression ("schtasks.exe {0}" -f $schtasksParams) | Out-File $tempfolder\$tempfile -Encoding utf8 -Force

    if(test-path $tempfolder\$tempfile){
        Import-Csv $tempfolder\$tempfile | Where-Object{$_.Hostname -ne "hostname"} | Select-Object -Property TaskName,@{N='Author';E={
            $gm = $_ | gm | Select-Object -ExpandProperty Name
                if($gm -contains "Author"){
                    $_.Author
                }
                else{
                    $_.Creator
                }
        }},@{N='Description';E={$_.Comment}},@{N='UserID';E={$_.'Run As User'}},@{N='Command';E={$_.'Task To Run'}},Arguments,Status
        Remove-Item -Path $tempfolder\$tempfile -Force
        #Get-Item $tempfolder | Where-Object{$_.GetType().Name -eq "DirectoryInfo"} | Remove-Item
    }
    else{
        throw ('Unable to find {0}\{1}' -f $tempfolder,$tempfile)
    }
}

function Get-ScheduledTaskModCSVXML
{
    [CmdletBinding()]
    param(
    [Alias('__Server','DNSHostName','IPAddress','Computer','Server')]
    [string]$ComputerName = $env:COMPUTERNAME)

    $XMLParams = '/query /XML ONE'
    $CSVParams = '/query /fo CSV'
    if($ComputerName -eq $env:COMPUTERNAME)
    {
        $XMLParams = '/query /XML ONE'
        $CSVParams = '/query /fo CSV'
    }
    else
    {
        $XMLParams = '/query /S {0} /XML ONE' -f $ComputerName
        $CSVParams = '/query /S {0} /fo CSV' -f $ComputerName    
    }
    $Tasks = invoke-expression ('schtasks.exe {0}' -f $XMLParams)
    $sk = invoke-expression ('schtasks.exe {0}' -f $CSVParams) | select-string -NotMatch '"TaskName","Next Run Time","Status"'
    $TasksStatuses = [System.Collections.ArrayList]@('"TaskName","Next Run Time","Status"')+[System.Collections.ArrayList]$sk
    $StatusList = $TasksStatuses | convertfrom-csv
    foreach ($Task in ([xml]$Tasks).Tasks.Task)
    {
        $TaskName = ($Task.PreviousSibling.InnerText -replace ' \\','').Trim()
        New-Object -TypeName psobject -Property (@{
            TaskName = $TaskName
            Author = $Task.RegistrationInfo.Author
            Description = $Task.RegistrationInfo.Description
            UserID = $Task.Principals.Principal.UserId
            Command = $Task.Actions.Exec.Command
            Arguments = $Task.Actions.Exec.Arguments
            Status = $StatusList | Where-Object {$_.TaskName.Remove(0,1) -eq $TaskName} | Select-Object -ExpandProperty Status
        })
    }
}

function Get-ScheduledTaskMod
{
    param(
    [Alias('__Server','DNSHostName','IPAddress','Computer','Server')]
    [string]$ComputerName = $env:COMPUTERNAME)
   
    if(($ComputerName -eq $env:COMPUTERNAME) -and (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)){ #the command may not exist in previous powershell versions
        Get-ScheduledTask -Verbose | Select-Object -Property TaskName,Author,Description,@{N='UserID';E={$_.Principal.UserId}},@{N='Command';E={$_.Actions | select-object -ExpandProperty Execute -ErrorAction SilentlyContinue}},@{N='Arguments';E={$_.Actions | select-object -ExpandProperty Arguments -ErrorAction SilentlyContinue}},@{N='Status';E={$_.State}}
    }
    else
    {
        try{
            Get-ScheduledTaskModCSVSMB -ComputerName $ComputerName -ErrorAction Stop
        }
        catch{
            try{
                Get-ScheduledTaskModCSVXML -ComputerName $ComputerName -ErrorAction Stop
            }
            catch{
                Write-Warning ("All methods of getting the list of scheduled tasks from computer {0} have failed. You may want to try using this command via Invoke-Command (PowerShell Remoting)" -f $ComputerName)
            }
        }
    }
}