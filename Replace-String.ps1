<#
.Synopsis
   Replace strings by given regex pattern with a random or serial number
.DESCRIPTION
   Long description
.AUTOR
   Amir Granot, Jul 2016
#>
function Replace-String
{
    [CmdletBinding(DefaultParameterSetName='FreeForm')]
    param(
    #one line string
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0,
                ParameterSetName='IPPattern')]
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0,
                ParameterSetName='Consistent')]
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0,
                ParameterSetName='FreeForm')]
    [Alias("CurrentString")]
    [AllowEmptyString()] #incoming lines can be empty, so applied because of the Mandatory flag
    [string]
    $InputObject,
    #regex pattern with 1 named capturing group at most
    [Parameter(Mandatory=$true, 
                Position=1,
                ParameterSetName='Consistent')]
    [Parameter(Mandatory=$true, 
                Position=1,
                ParameterSetName='FreeForm')]
    [string]
    $Pattern,
    #value can contain {0} so counter value will be added
    [Parameter(Mandatory=$true, 
            Position=2,
            ParameterSetName='Consistent')]
    [Parameter(Mandatory=$true, 
            Position=2,
            ParameterSetName='FreeForm')]
    [string]
    $NewValue,
    [Parameter(Mandatory=$true,ParameterSetName='IPPattern')]
    [switch]
    $IPPattern,
    #can be global in the script instead of a parameter in this function. # need to think about it
    #required if -AsObject | -Consistent (not dependent on them)
    [Parameter(Mandatory=$false,#true
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false,
                ParameterSetName='IPPattern')]
    [Parameter(Mandatory=$false,#true
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false,
                ParameterSetName='Consistent')]
    [Parameter(Mandatory=$false,
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                ParameterSetName='FreeForm')]
    [int]
    $LineNumber,
    #ConvertionTable is required if -Consistent (and maybe consistent is irrelevant if this parameter exists? - can serve 2 purposes)
    [Parameter(Mandatory=$true,ParameterSetName='IPPattern')]
    [Parameter(Mandatory=$false,ParameterSetName='Consistent')]
    [HashTable]
    $ConvertionTable,
    #output as object (with line number and instead of a single line
    #will work only if the data was changed
    #format parameter
    [Parameter(Mandatory=$false,ParameterSetName='IPPattern')]
    [Parameter(Mandatory=$false,ParameterSetName='Consistent')]
    [Parameter(Mandatory=$false,ParameterSetName='FreeForm')]
    [switch]
    $AsObject)

    Begin{
        if(-not $LineNumber){
            $LineNumber = 0
        }
    }

    Process{

        $changed = $false

        if($IPPattern){
            $Pattern = "\b(\d{1,3}(\.\d{1,3}){3})\b" # \b with or without it makes a slight difference
        }

        #not Consistent
        if(-not $ConvertionTable){
            $result = $InputObject -replace $Pattern,($NewValue -f $LineNumber)
            if($AsObject){ #save time
                $changed = $result -ne $InputObject
            }        
        }
        else{#Consistent
            #match pattern?
            $result = if($InputObject -match $Pattern){
                #Capturing Group Name is set
                $NamedPattern = $Matches[0]
                Write-Verbose "`$NamedPattern = $NamedPattern"
                #Does this lexeme already exist in the ConvertionTable?
                if($ConvertionTable[$NamedPattern] -eq $null){
                    #IPPattern
                    if($IPPattern){
                        [int]$t = $LineNumber
                        $o4 = ($t % 254) + 1
                        $t = $t / 254
                        $o3 = $t % 254
                        $t = $t / 254 
                        $o2 = $t % 254
                        $t = $t / 254
                        $o1 = $t % 254 + 11

                        $NewValue = "$o1.$o2.$o3.$o4"
                    }
                    #This pattern doesn't exist in the ConvertionTable, add it with line number (if specified in the NewValue)
                    Write-Verbose "adding new value to the convertion table"
                    $ConvertionTable[$NamedPattern] = $NewValue -f $LineNumber
                    Write-Verbose "`$ConvetionTable[$NamedPattern] = $($ConvertionTable[$NamedPattern])"
                }
                #This pattern exists, use it.
                $InputObject -replace [regex]::Escape($NamedPattern),$ConvertionTable[$NamedPattern] #$InputObject -replace $NamedPattern,$ConvertionTable[$NamedPattern]

                $changed = $true
            }
            else{
                #Not match pattern
                $InputObject
            }
        }

        #Only if result is different from the input object
        if($AsObject){
            New-Object -TypeName PSCustomObject -Property @{
                CurrentString = $result
                Pattern       = $Pattern
                NewValue      = $NewValue
                Original      = $InputObject
                Result        = $result
                LineNumber    = $LineNumber
                Changed       = $changed
            } | Select-Object CurrentString,Pattern,NewValue,LineNumber,Original,Result,Changed
        }else{
            $result
        }

        $LineNumber++
    }#Process
}