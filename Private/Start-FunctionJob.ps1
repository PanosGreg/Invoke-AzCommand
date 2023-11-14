function Start-FunctionJob {
[CmdletBinding()]
param (
    [string]$CommandName,
    [System.Collections.Hashtable]$ParameterTable
)

# Start new job that executes a copy of this function against the remaining parameter arguments
$block = {
    param(
        [string]$FunctionName,
        [System.Collections.IDictionary]$ArgTable,
        [string]$ModulePath
    )

    Import-Module $ModulePath

    $ProgressPreference = 'SilentlyContinue'  # <-- since we're in a job, no need to show progress

    & $FunctionName @ArgTable
}

$Random = [System.Guid]::NewGuid().Guid.Substring(32)
$Path   = $MyInvocation.MyCommand.Module.ModuleBase
$params = @{
    ScriptBlock   = $block
    ArgumentList  = $CommandName,$ParameterTable,$Path
    StreamingHost = $Host
    Name          = "AzCmd-$Random"
}
$job = Start-ThreadJob @params
$job | Add-Member -NotePropertyMembers @{TargetVM=$ParameterTable.VM.Name.ToUpper()}

Write-Output $job
}