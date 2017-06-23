function Get-ObjectProperty
{
    <#
    .SYNOPSIS
    Expands a given object recursively.
    Can filter by given property name with regex pattern.
    
    .DESCRIPTION
    Expands a given object recursively.
    Can filter by given property name with regex pattern.

    Written by: Amir Granot.
    Blog      : http://granola.tech
    GitHub    : http://github.com/DCAG
    
    .PARAMETER InputObject
    The object to expand
    
    .PARAMETER Property
    regex pattern of property to look for
    
    .PARAMETER Depth
    level of recursion.
    0 - is the direct properties of the object (like format-list * -force)
    1 - is the properties of the properties
    ...
    limited to 100 levels of recursion.
    
    .PARAMETER ExpandCollections
    Allow expansions of collections to see a list of members

    .EXAMPLE
    Get-ObjectProperty -InputObject (Get-Process)[0] -Property 'Memory'
    [ORIGIN].NonpagedSystemMemorySize: 17736
    [ORIGIN].NonpagedSystemMemorySize64: 17736
    [ORIGIN].PagedMemorySize: 3522560
    [ORIGIN].PagedMemorySize64: 3522560
    [ORIGIN].PagedSystemMemorySize: 214744
    [ORIGIN].PagedSystemMemorySize64: 214744
    [ORIGIN].PeakPagedMemorySize: 4165632
    [ORIGIN].PeakPagedMemorySize64: 4165632
    [ORIGIN].PeakVirtualMemorySize: 127922176
    [ORIGIN].PeakVirtualMemorySize64: 127922176
    [ORIGIN].PrivateMemorySize: 3522560
    [ORIGIN].PrivateMemorySize64: 3522560
    [ORIGIN].VirtualMemorySize: 111177728
    [ORIGIN].VirtualMemorySize64: 111177728
    [ORIGIN].MainModule.ModuleMemorySize: 307200
    
    .NOTES
    Does not further expand objects that were already expanded somewhere inside the recusion tree (saves a record of object hashes)
    Does not expand collections items' properties.

    .LINK
    http://granola.tech

    .LINK
    http://github.com/DCAG
    #>
    [Cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [object]$InputObject,
        [string]$Property,
        [ValidateRange(0,100)]
        [int]$Depth = 3,
        [switch]$ExpandCollections)

    Begin{
        function Get-InnerObjectProperty{
            param($InputObject, $Property, $Depth, [switch]$ExpandCollections, $Path = "[ORIGIN]", [Int32[]]$__Table = @()) #do not change input for $__Table
            $__Table += $InputObject.GetHashCode()
            $InputObject.psobject.Properties.where({$_.IsGettable -and $_.Name -match $Property}).foreach({
                if($ExpandCollections -and $_.Value -ne $null -and $_.Value.psobject.typenames.where({$_ -match 'Collection|Array'})){
                    $Name = $_.Name
                    $_.Value | ForEach-Object {$i = 0} {
                        '{0}.{1}[{2}]: {3}' -f $Path, $Name, $i, $_
                        $i += 1
                    }
                }else{
                    '{0}.{1}: {2}' -f $Path, $_.Name, $_.Value
                }
            })
            if($Depth -gt 0){
                $Depth = $Depth-1
                $InputObject.psobject.Properties.where({$_.IsGettable}).where({$_.Value -ne $null -and $__Table -notcontains $_.Value.GetHashCode()}).foreach({ Get-InnerObjectProperty -InputObject $_.Value -Property $Property -Path "$Path.$($_.Name)" -Depth $Depth -__Table $__Table })
            }
        }
    }

    Process{
        Get-InnerObjectProperty -InputObject $InputObject -Property $Property -Depth $Depth -ExpandCollections:$ExpandCollections
    }
}