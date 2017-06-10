
function Get-OutputEncoding{
    if($Host.Name -eq 'ConsoleHost'){
        [Console]::OutputEncoding.HeaderName
    }else{
        $OutputEncoding.HeaderName
    }
}

<#
.Synopsis
    Enables an administrator to list or disconnect files and folders
    that have been opened on a system.
.DESCRIPTION
   written by Amir Granot, Jan 2015.
      
   Last modified by: Amir Granot, Apr 2016.
   
   This function wraps the openfiles.exe program provided in windows.
   The return value is an array of objects.
.EXAMPLE
    Get-SMBFileHandle -ComputerName fs1 | Format-Table -AutoSize

    Hostname              ID        AccessedBy Type    Locks OpenMode     Path                                                                                                                                       
    --------              --        ---------- ----    ----- --------     ----                                                                                                                                       
    
.EXAMPLE
    Get-SMBFileHandle fs1 | Where-Object{$_.'AccessedBy' -eq "amir"}


    Hostname                    : myDom.dom
    ID                          : 349398070
    Accessed By                 : amir
    Type                        : Windows
    #Locks                      : 0
    Open Mode                   : Read
    Open File (Path\executable) : \folder\folder2

    Hostname                    : myDom.dom
    ID                          : 169398071
    Accessed By                 : amir
    Type                        : Windows
    #Locks                      : 0
    Open Mode                   : Read
    Open File (Path\executable) : \folder\folder2\file1.txt

.EXAMPLE
    Get-SMBFileHandle -ComputerName fs1 | Where-Object{$_.Path -like "*Sysinternals*"} | Format-Table -AutoSize

    Hostname  ID        AccessedBy Type    Locks OpenMode Path                    
    --------  --        ---------- ----    ----- -------- ----                    
    myDom.dom 906333100 amir       Windows 0     Read     Sysinternals\Procmon.exe
    myDom.dom 680336200 amir       Windows 0     Read     Sysinternals\PROCEXP.EXE
.INPUTS
   Computername is the remote server or storage machine to query
.OUTPUTS
   array of custom objects
.NOTES
   In oprder to run this command one needs to be an administrator on the remote machine or storage.
.FUNCTIONALITY
   PowerShell wrapper of the OPENFILES.EXE program.
#>
function Get-SMBFileHandle{
    [CmdletBinding(SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  ConfirmImpact='Medium')]
    param(
    # Name of computer, server or storage share
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0)]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ComputerName,

    [ValidateSet("UTF-8","UTF-7","Unicode","US-ASCII","UTF-16BE","UTF-32")]
    [String]
    $Encoding = (Get-OutputEncoding),

    [System.Management.Automation.PSCredential]
    $Credentials
    )

    if($Host.Name -eq 'ConsoleHost'){
        $OLDEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($Encoding)
    }
    else{
        $OLDEncoding = $OutputEncoding
        $OutputEncoding = [System.Text.Encoding]::GetEncoding($Encoding)
    }
    
    
    $result = if($Credentials -ne $null)
    {
        openfiles /query /s $ComputerName /U $Credentials.UserName /P $Credentials.GetNetworkCredential().Password /V /fo CSV | ConvertFrom-Csv
    }
    else{
        openfiles /query /s $ComputerName /V /fo CSV | ConvertFrom-Csv
    }

    $result | select-object -property HostName,ID,@{N="AccessedBy";E={$_.'Accessed By'}},Type,@{N='Locks';E={$_.'#Locks'}},@{N='OpenMode';E={$_.'Open Mode'}},@{N='Path';E={$_.'Open File (Path\executable)'}}

    [Console]::OutputEncoding = $OLDEncoding
}

<#
.Synopsis
    Enables an administrator to disconnect files and folders that
    have been opened remotely through a shared folder.
.DESCRIPTION
   written by Amir Granot, Jan 2015.
      
   Last modified by: Amir Granot, Apr 2016.
.EXAMPLE
   First, retrieve the files and ensure that these are the files you want to disconnect

   PS C:\> Get-SMBFileHandle -ComputerName fs1 | Where-Object{$_.Path -like "*Amir*"} | Format-Table -AutoSize

   Hostname  ID        AccessedBy Type    Locks OpenMode Path                                     
   --------  --        ---------- ----    ----- -------- ----                                     
   myDom.dom 453586547 amir       Windows 0     Write    amir\example.txt                         
   myDom.dom 453582502 amir       Windows 0     Read     \Amir                                    
   myDom.dom 453582489 amir       Windows 0     Read     Amir\installer
   myDom.dom 453574025 amir       Windows 0     Read     \Amir                                    
   myDom.dom 453573941 amir       Windows 0     Read     \Amir                                    

   Secondly, use Disconnect-SMBFileHandle to disconnect the file handles from the server 

   PS C:\> Get-SMBFileHandle -ComputerName fs1 | Where-Object{$_.Path -like "*Amir*"} | Disconnect-SMBFileHandle -Verbose
   VERBOSE: Disconnecting file handle from server myDom.dom ID:453586547

   SUCCESS: The connection to the open file "amir\example.txt" has been terminated.
   VERBOSE: Disconnecting file handle from server myDom.dom ID:453582502

   SUCCESS: The connection to the open file "\Amir" has been terminated.
   VERBOSE: Disconnecting file handle from server myDom.dom ID:453582489

   SUCCESS: The connection to the open file "Amir\installer" has been terminated.
   VERBOSE: Disconnecting file handle from server myDom.dom ID:453574025

   SUCCESS: The connection to the open file "\Amir" has been terminated.
   VERBOSE: Disconnecting file handle from server myDom.dom ID:453573941

   SUCCESS: The connection to the open file "\Amir" has been terminated.
.EXAMPLE
   Use the handles' ID's as parameter to the function (must specify ComputerName also).
   
   PS C:\> Disconnect-SMBFileHandle -ComputerName fs1 -ID 463611508,353600586,353586497 -Verbose
   VERBOSE: Disconnecting file handle from server fs1 ID:463611508
   VERBOSE: Disconnecting file handle from server fs1 ID:353600586

   SUCCESS: The connection to the open file "\Amir" has been terminated.
   VERBOSE: Disconnecting file handle from server fs1 ID:353586497

   SUCCESS: The connection to the open file "Amir\installer" has been terminated.
.INPUTS
   The IDs of the file handles to disconnect & ComputerName
   -OR-
   Products from function Get-SMBFileHandle (via pipeline or as parameter -OpenFile)
.NOTES
    Notice! After using this function, in order to see the change you must run the function Get-SMBFileHandle
.OUTPUTS
   None.
.FUNCTIONALITY
   PowerShell wrapper of the OPENFILES.EXE program.
#>
function Disconnect-SMBFileHandle{
    [CmdletBinding(DefaultParameterSetName='Parameter Set 1', 
                  SupportsShouldProcess=$true, 
                  PositionalBinding=$false,
                  ConfirmImpact='High')]
    param(
    # Name of computer, server or storage share
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0,
                ParameterSetName="Set 1")]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ComputerName,
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=1,
                ParameterSetName="Set 1")]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [int[]]$ID,
    #OpenFile data object recieved from Get-SMBFileHandle function.
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0,
                ParameterSetName="Set 2")]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [object[]]
    $OpenFile,

    [Parameter(ParameterSetName="Set 1")]
    [Parameter(ParameterSetName="Set 2")]
    [System.Management.Automation.PSCredential]
    $Credentials
    )
    process{

        switch($PSCmdlet.ParameterSetName)
        {
            "Set 1" {
                @($ID) | ForEach-Object{
                    if($pscmdlet.ShouldProcess($_,"Disconnecting File Handle from server $ComputerName")){ #Printed when these flags are used: -verbose, -whatif. Also requires confirmation on operation
                        if($Credentials -eq $null)
                        {
                            OPENFILES /Disconnect /S $ComputerName /ID $_
                        }
                        else{
                            OPENFILES /Disconnect /S $ComputerName /ID $_ /U $Credentials.UserName /P $Credentials.GetNetworkCredential().Password
                        }
                    }
                }
                break;
            }
            "Set 2" {
                @($OpenFile) | ForEach-Object{
                    if($pscmdlet.ShouldProcess($_.ID,"Disconnecting File Handle from server $($_.Hostname)")){ #Printed when these flags are used: -verbose, -whatif. Also requires confirmation on operation
                        if($Credentials -eq $null)
                        {
                            OPENFILES /Disconnect /S $_.Hostname /ID $_.ID
                        }
                        else{
                            OPENFILES /Disconnect /S $_.Hostname /ID $_.ID /U $Credentials.UserName /P $Credentials.GetNetworkCredential().Password
                        }
                    }
                }
                break;
            }
        }#end switch
    }
}#end function

function Get-SMBFileHandleGUI{
    Write-Host @"
    
"@
}

new-alias gsfh Get-SMBFileHandle
new-alias dsfh Disconnect-SMBFileHandle

Export-ModuleMember -Function 'Get-SMBFileHandle', 'Disconnect-SMBFileHandle' -alias 'gsfh', 'dsfh'