function Invoke-RemoteScript {
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$ScriptString,

    [Alias('ResourceGroupName')]
    [Parameter(Mandatory)]
    [string]$RGName,

    [Alias('ComputerName')]
    [string]$VMName,

    [int]$Timeout = 180  # <-- default 3 minutes
)

# helper function for error logging
function Pre {"`r[{0} {1}]" -f (Get-Date -F 'HH:mm:ss'),$VMName.ToUpper()}

# run the remote command as a background job
$params = @{
    ResourceGroupName = $RgName
    VMName            = $VMName
    CommandId         = 'RunPowerShellScript'
    ScriptString      = $ScriptString
    AsJob             = $true
    ErrorAction       = 'Stop'
    Verbose           = $false
}
try {
    Write-Verbose "$(Pre) Executing command..."
    $job = Invoke-AzVMRunCommand @params
}
catch {
    Write-Warning "$(Pre) There was an issue with AzVMRunCommand"
    $msg = $_.Exception.Message.Split("`n") | where {$_ -match 'Error(Code|Message)'}
    foreach ($AzVMError in $msg) {
        Write-Error "$(Pre) $AzVMError"
    }
    return
}

# collect the output
$job | Wait-Job -Timeout $Timeout | Out-Null
if ($job.State -eq 'Running') {
    Write-Warning "$(Pre) InvokeAzVMRunCommand timeout exceeded, stopping command"
    $job | Stop-Job -PassThru -Verbose:$false | Remove-Job -Force -Verbose:$false
    return
}
else {
    $Result = $job | Receive-Job
    if ($Result.Value.Message) {
        $StdOut = $Result.Value.Message[0]
        $StdErr = $Result.Value.Message[1]
    }
    $job | Remove-Job -Verbose:$false
}

# show any errors
if ([bool]$StdErr) {
    Write-Warning "$(Pre) There was one or more errors in the output"
    Write-Error $StdErr
}

# show the output
if ([bool]$StdOut) {
    [pscustomobject] @{
        VMName = $VMName
        Output = $StdOut  # <-- base64 compressed string 
    }
}
}