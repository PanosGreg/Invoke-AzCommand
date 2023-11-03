function Invoke-ForEachParallel {
<#
.SYNOPSIS
    This is a wrapper around foreach-parallel from PS v7, but with progress bars.

.DESCRIPTION
    This is a wrapper around foreach-parallel from PS v7, but with progress bars.

    You can run a scriptblock against an array of objects, just like foreach,
    but it also shows multi-threaded progress bars, one for every thread.

    The end-user can also use a custom automatic variable, $ProgressStatus,
    which updates the progress message.
.EXAMPLE
    $test = 'test123'
    $list = Get-Service | Select-Object -First 5
    Invoke-ForEachParallel -InputObject $list -ScriptBlock {
        $ProgressStatus = 'Initializing...'
        Start-Sleep -Milliseconds (Get-Random -Minimum 1000 -Maximum 2000)
        $ProgressStatus = 'Enumerating...'
        [pscustomobject] @{
            Name   = $_.Name
            Status = $_.Status
            Test   = $using:test
        }
        Start-Sleep -Milliseconds (Get-Random -Minimum 1000 -Maximum 2000)
    } -ThrottleLimit 2 -ActivityProperty Name

    # this will spin up 2 parallel threads for the user's scriptblock
    # it uses the automatic variable $ProgressStatus to show progress messages
    # it also uses the ActivityProperty to define the activity label
    # if the user does not provide an ActivityProperty, then a default label will be shown
    # finally, in the scriptblock we also have a $using: variable to pass ad-hoc data inside.
.NOTES
    The initial idea and code comes from:
    https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/write-progress-across-multiple-threads
#>
[cmdletbinding()]
param (
    [Parameter(Mandatory,Position=0)]
    $InputObject,

    [Parameter(Mandatory,Position=1)]
    [scriptblock]$ScriptBlock,

    [Parameter(Position=2)]
    [string]$ActivityProperty,

    [Parameter(Position=3)]
    [ValidateScript(
        {$_ -ge 1 -and $_ -le [System.Environment]::ProcessorCount*3},
        ErrorMessage = 'Please enter a number between 1 and up to triple the number of your CPU threads'
    )]
    [int]$ThrottleLimit = 10
)

#requires -Version 7.0
# Note: The foreach -Parallel parameter is only available on PS 7+
#       Also the ErrorMessage in the ValidateScript is only available on PS 6+

# we need to check that the ActivityProperty is actually a property of the InputObject
if ($PSBoundParameters.ContainsKey('ActivityProperty')) {
    $HasProperty = ($InputObject | Get-Member -MemberType Properties).Name -contains $ActivityProperty
    if (-not $HasProperty) {
        Write-Warning "The property $ActivityProperty was not found in the given input object"
        return
    }
}
else {$HasProperty = $false}  # <-- that means we need to add a default activity label of our own

# Progress Bar with ForEach Parallel, related variables and setup
$ProgressParams  = [System.Collections.Concurrent.ConcurrentDictionary[int,hashtable]]::new()
$ProgressIDNum   = 0
$InputListWithID = $InputObject | foreach {
    $ProgressIDNum++
    [void]$ProgressParams.TryAdd($ProgressIDNum,@{})

    if ($HasProperty) {$Label = $_.$ActivityProperty}
    else              {$Label = "Thread #$ProgressIDNum"}

    [pscustomobject] @{
        ProgressID    = $ProgressIDNum
        ActivityLabel = $Label
        UserObject    = $_
    }
}
$ActivityLength = ($InputListWithID.ActivityLabel | Measure-Object -Property Length -Maximum).Maximum

$ParallelBlock = {
    # Progress Bar related variables
    $_HashCopy = $using:ProgressParams        # <-- copy of the Concurrent Dictionary [int,hashtable]
    $_progress = $_HashCopy.$($_.ProgressID)  # <-- $progress is a hashtable
    $_Padding           = $using:ActivityLength - $_.ActivityLabel.Length
    $_progress.Id       = $_.ProgressID
    $_progress.Activity = "[{0}{1}]" -f $_.ActivityLabel,(' '*$_Padding)

    # the $ProgressStatus custom automatic variable that updates the progress message
    $_BreakAction = {$global:_progress.Status = (Get-Variable ProgressStatus).Value}
    Set-PSBreakpoint -Variable ProgressStatus -Action $_BreakAction -Mode Write | Out-Null
    [string]$ProgressStatus = 'Processing...'  # <-- that's the default progress message

    # user's scriptblock
    $PSItem = $PSItem.UserObject    # <-- set the current item to the user's object
    
    ## the user can use the automatic variable $ProgressStatus to show progress messages
    ## we need to place the user's code as-is, else any $using variables won't be respected

    '@USERCODE@'

    # in the end, mark progress as completed
    $_progress.Completed = $true
}

# build the parallel scriptblock
$SB = [System.Text.StringBuilder]::new($ParallelBlock.ToString())
[void]$SB.Replace("'@USERCODE@'",$ScriptBlock.ToString())
$NewBlock = [scriptblock]::Create($SB.ToString())

# run the command with multi-threading and progress bars
$params = @{
    Parallel      = $NewBlock
    ThrottleLimit = $ThrottleLimit
    Verbose       = $true
    AsJob         = $true
}
$Job = $InputListWithID | ForEach-Object @params

while ($Job.State -eq 'Running') {
    $ProgressParams.Keys | foreach {
        if (([array]$ProgressParams.$_.Keys).Count -ge 1) {
            $params = $ProgressParams.$_
            Write-Progress @params
        }
    }
    # Wait to refresh to not overload gui
    Start-Sleep -Milliseconds 100
}

# show the results
$Job | Receive-Job -Verbose -AutoRemoveJob -Wait
}