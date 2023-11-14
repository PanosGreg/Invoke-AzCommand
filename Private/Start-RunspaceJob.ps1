function Start-RunspaceJob {
[cmdletbinding()]
param (
    [Parameter(Mandatory)]
    [scriptblock]$Scriptblock,

    [object[]]$ArgumentList,

    [hashtable]$ParameterList,

    [int]$Timeout,

    [pscredential]$RunAs
)

. ([scriptblock]::Create('using namespace System.Management.Automation'))  # PSDataCollection,PowerShell,Runspaces.*
$State = [Runspaces.InitialSessionState]::CreateDefault()

# add the required context to run as a different user
if ($RunAs) {
    $MyFunc   = Get-Item Function:\Invoke-WithImpersonation -ErrorAction Stop
    $VarEntry = [Runspaces.SessionStateVariableEntry]::new('_Creds',$RunAs,$null)
    $FunEntry = [Runspaces.SessionStateFunctionEntry]::new($MyFunc.Name,$MyFunc.Definition)
    [void]$State.Commands.Add($FunEntry)
    [void]$State.Variables.Add($VarEntry)
}

# create a new powershell runspace
$cmd = [PowerShell]::Create($State)

# add the scriptblock
if ($RunAs) {
    [void]$cmd.AddScript("`$ScriptString = @'`n$($Scriptblock.ToString())`n'@")
    [void]$cmd.AddScript('Invoke-WithImpersonation -Credential $_Creds -ScriptString $ScriptString')
}
else {
    [void]$cmd.AddScript($Scriptblock.ToString())
}

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