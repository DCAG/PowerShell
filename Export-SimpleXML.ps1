Function Export-SimpleXML
{
    <#
    .SYNOPSIS
    Export object to simple xml formatted file.
    
    .DESCRIPTION
    Export object to simple xml, unlike Export-CLIXML on Convert-XML which add "noise" to the result document
    this function export the object as simple xml where the elements names are the property names inside the object (and decendent objects).    
    
    Written by: Amir Granot.
    Blog      : http://granola.tech
    GitHub    : http://github.com/DCAG

    .PARAMETER InputObject
    The object to serialize.
    
    .PARAMETER Path
    Output path of the result document.
    
    .PARAMETER Depth
    Depth of nested objects to serialize. default is 1.
    #>
    [CmdletBinding()]
    param(
    [Parameter(ValueFromPipeline=$true,Position=0,Mandatory=$true)]
    [object[]]$InputObject,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [int]$Depth = 1)

    Begin{
        [System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq")
        $collection = New-Object System.Collections.ArrayList
    }
    Process{
        $collection.Add($InputObject) | Out-Null
    }
    End
    {
        $XMLString = $collection | ConvertTo-Xml -As String -NoTypeInformation -Depth $Depth
        $XMLDoc = [System.Xml.Linq.XDocument]::Parse($XMLString)

        foreach($element in $XMLDoc.Descendants())
        {
            if($element.Attributes().Value)
            {
                $element.Name = $element.Attributes().Value
                $element.Attributes().Remove()
            }
        }
        $XMLDoc.Save($Path)
    }
}