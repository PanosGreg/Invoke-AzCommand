function Start-RunspaceJob {
[cmdletbinding()]
param (
    [Parameter(Mandatory)]
    [scriptblock]$Scriptblock,

    [object[]]$ArgumentList,

    [hashtable]$ParameterList,

    [int]$Timeout
)

# create a new powershell using the default configuration for a runspace
$cmd = [PowerShell]::Create()

# add the scriptblock
[void]$cmd.AddScript($Scriptblock.ToString())

# add any user arguments (either Args OR Params, NOT both)
if ($ArgumentList.Count -gt 0) {
    $ArgumentList | foreach {[void]$cmd.AddArgument($_)}
}
elseif ($ParameterList.Keys.Count -gt 0) {
    $ParameterList.GetEnumerator() | foreach {[void]$cmd.AddParameter($_.Key,$_.Value)}
}

# get all streams as part of the normal output, not separately
$cmd.Commands.Commands.MergeMyResults('All','Output')

$InOut = [System.Management.Automation.PSDataCollection[object]]::new()
$Async = $cmd.BeginInvoke($InOut,$InOut)

if ($Timeout) {
    $Timer  = [System.Diagnostics.Stopwatch]::StartNew()
    $IsDone = $false ; $HasExpired = $false
    while (-not $IsDone -and -not $HasExpired) {
        $IsDone = $Async.IsCompleted
        $HasExpired = $Timer.Elapsed.TotalSeconds -gt $Timeout
        Start-Sleep -Milliseconds 500
    }
    $Timer.Stop()
    if (-not $Async.IsCompleted) {
        Write-Warning "Execution timeout has expired ($Timeout sec) but the script is still running" 3>&1
        Write-Warning 'Will only collect output till this point, if any.' 3>&1
        $cmd.Stop()
    }
}

try   {$cmd.EndInvoke($Async)}   # <-- this will wait as long as needed for the script to finish
catch {$_.Exception.InnerException.ErrorRecord}

$cmd.Dispose()
Remove-Variable cmd -Verbose:$false

Write-Output $InOut
}