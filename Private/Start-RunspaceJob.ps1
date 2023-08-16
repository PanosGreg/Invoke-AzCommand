function Start-RunspaceJob {
[cmdletbinding()]
param (
    [Parameter(Mandatory)]
    [scriptblock]$Scriptblock,
    [object[]]$ArgumentList,
    [int]$Timeout
)

# create a new powershell using the default configuration for a runspace
$cmd = [PowerShell]::Create()

# add the scriptblock and any arguments
[void]$cmd.AddScript($Scriptblock.ToString())
$ArgumentList | foreach {[void]$cmd.AddArgument($_)}

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
else {$cmd.EndInvoke($Async)}  # <-- this will wait as long as needed for the script to finish

$cmd.Dispose()
Remove-Variable cmd -Verbose:$false

Write-Output $InOut
}