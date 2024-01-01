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
    $FunEntry = [Runspaces.SessionStateFunctionEntry]::new($MyFunc.Name,$MyFunc.Definition)
    [void]$State.Commands.Add($FunEntry)

    $VarEntry1 = [Runspaces.SessionStateVariableEntry]::new('_Creds',$RunAs,$null)
    $VarEntry2 = [Runspaces.SessionStateVariableEntry]::new('_UserBlock',$Scriptblock,$null)
    [void]$State.Variables.Add($VarEntry1)
    [void]$State.Variables.Add($VarEntry2)

    [void]$PSBoundParameters.Remove('Scriptblock')
    [void]$PSBoundParameters.Remove('RunAs')
    [void]$PSBoundParameters.Remove('Timeout')
    
    # so now the $PSBoundParameters is either empty or
    # it's a hashtable that has a single Key which is either ArgumentList or ParameterList
    $VarEntry3 = [Runspaces.SessionStateVariableEntry]::new('_UserArgs',$PSBoundParameters,$null)
    [void]$State.Variables.Add($VarEntry3)
}

# create a new powershell runspace
$cmd = [PowerShell]::Create($State)

# add the scriptblock & any arguments
if ($RunAs) {
    [void]$cmd.AddScript('Invoke-WithImpersonation -ScriptBlock $_UserBlock -Credential $_Creds @_UserArgs')
}
else {
    [void]$cmd.AddScript($Scriptblock.ToString())

    # add user's parameters (can add args/params only after you add a script first)
    if ($ArgumentList.Count -gt 0) {
        $ArgumentList | foreach {[void]$cmd.AddArgument($_)}
    }
    elseif ($ParameterList.Keys.Count -gt 0) {
        $ParameterList.GetEnumerator() | foreach {[void]$cmd.AddParameter($_.Key,$_.Value)}
    }

}

# get all streams as part of the normal output, not separately
$cmd.Commands.Commands.MergeMyResults('All','Output')

$InOut = [PSDataCollection[object]]::new()
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

try   {[void]$cmd.EndInvoke($Async)}   # <-- this will wait as long as needed for the script to finish
catch {$_.Exception.InnerException.ErrorRecord}

$cmd.Dispose()
Write-Output $InOut
}

#  NOTE: the .EndInvoke() does actually output $null, which is caught by the caller of the function.
#        So you have to silence it via out-null or use [void].