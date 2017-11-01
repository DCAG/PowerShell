<#
.DESCRIPTION
Format Get-Counter output as a table where each column is dedicated to results from one server, and each line is a timestamp.

Written by: Amir Granot.
Blog      : http://granola.tech
GitHub    : http://github.com/DCAG

.EXAMPLE
TimeStamp           DC1
---------           ---
01/11/2017 21:41:26 16.54
01/11/2017 21:41:31 8.96
01/11/2017 21:41:36 4.55
01/11/2017 21:41:41 6.84
01/11/2017 21:41:46 14.53
01/11/2017 21:41:51 7.75
01/11/2017 21:41:56 8.31
01/11/2017 21:42:01 3.83
01/11/2017 21:42:06 9.61
01/11/2017 21:42:11 14.57
#>

#Requires -Version 4

$Servers = @('DC1')

$CounterParameters = @{
    Counter = '\Processor(_Total)\% Processor Time'
    SampleInterval = 5
    MaxSamples = 10
    ComputerName = $Servers
}

Get-Counter @CounterParameters | ForEach-Object {
    $Properties = [ordered]@{TimeStamp = $_.TimeStamp}
    $_.CounterSamples | ForEach-Object{
        $null = $_.Path -match '^\\\\(?<PerfSubject>.*?)\\\\?'
        $Properties.Add($Matches['PerfSubject'], '{0:n}' -f $_.CookedValue)
    }

    New-Object -TypeName PSCustomObject -Property $Properties
} | Format-Table