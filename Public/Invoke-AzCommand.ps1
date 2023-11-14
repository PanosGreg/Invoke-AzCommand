function Invoke-AzCommand {
<#
.SYNOPSIS
    It runs a remote command in an Azure VM through Invoke-AzVMRunCommand,
    but it adds support for objects, streams and multi-threading.
.EXAMPLE
    Invoke-AzCommand -VM (Get-AzVM) -ScriptBlock {$PSVersionTable}
    # we get an object as output
.EXAMPLE
    Invoke-AzCommand (Get-AzVM) {param($Svc) $Svc.Name} -Arg (Get-Service WinRM)
    # we give an object for input
.EXAMPLE
    $All = Get-AzVM
    Invoke-AzCommand $All {Write-Verbose 'vvv' -Verbose;Write-Warning 'www';Write-Output 'ooo'}
    # we get different streams in the output
.EXAMPLE
    Please see the examples.md file for more use-cases and examples.
#>
[CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
param (
    [Parameter(Mandatory,Position=0)]
    [ValidateScript({
        $Chk = $_ | foreach {$_.GetType().Name -match 'PSVirtualMachine(List|ListStatus)?$'}
        $Chk -notcontains $false},
        ErrorMessage = 'Please provide a valid Azure VM object type'
    )]
    $VM,  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus]

    [Parameter(Mandatory,Position=1,ParameterSetName = 'ScriptBlock')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'BlockAndArgs')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'BlockAndParams')]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory,Position=1,ParameterSetName = 'ScriptFile')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'FileAndArgs')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'FileAndParams')]
    [string]$ScriptFile,

    [Parameter(Mandatory,Position=2,ParameterSetName = 'BlockAndArgs')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'FileAndArgs')]
    [object[]]$ArgumentList,

    [Parameter(Mandatory,Position=2,ParameterSetName = 'BlockAndParams')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'FileAndParams')]
    [hashtable]$ParameterList,

    [switch]$AsJob,
    [int]$ThrottleLimit    = 10,    # <-- maximum number of parallel threads used during execution, default is 10
    [int]$DeliveryTimeout  = 666,   # <-- time needed to run the Invoke-AzVMRunCommand, default 10+ minutes (ExecTime plus 1+ minute for AzVMRunCommand to reach the Azure VM)
    [int]$ExecutionTimeout = 600,   # <-- this is the time needed to run the script on the remote VM
    [pscredential]$Credential
)

if ($AsJob) {
    # Remove the -AsJob parameter, leave everything else as-is
    [void]$PSBoundParameters.Remove('AsJob')

    $params = @{
        CommandName    = $MyInvocation.MyCommand.Name
        ParameterTable = $PSBoundParameters
    }
    return (Start-FunctionJob @params)
} #if AsJob

# get the user's script and arguments (if any)
$ParamSetName = $PSCmdlet.ParameterSetName
if ($ParamSetName -like '*File*') {
    $File = Get-Item $ScriptFile -ErrorAction Stop                        # <-- this checks if the file exists
    if ($File.Length -gt 1MB) {throw "Scriptfile too big. $ScriptFile is $($File.Length) bytes"}
    try   {$ScriptText  = Get-Content $ScriptFile -Raw -ErrorAction Stop  # <-- this checks if the file is accessible
           $ScriptBlock = [scriptblock]::Create($ScriptText)}             # <-- this checks if it's a PowerShell script
    catch {throw $_}
}
if     ($ParamSetName -like '*Args')   {$UserArgs = @{ArgumentList  = $ArgumentList}}
elseif ($ParamSetName -like '*Params') {$UserArgs = @{ParameterList = $ParameterList}}
else                                   {$UserArgs = @{}}

# assemble the script that we'll run on the remote VM
$RemoteScript = if (-not $Credential) {
    Write-RemoteScript $ScriptBlock @UserArgs -Timeout $ExecutionTimeout
}
else {
    Write-RemoteScript $ScriptBlock @UserArgs -Timeout $ExecutionTimeout -Credential $Credential
}

# create the scriptblock that we'll run in parallel
$Root  = $MyInvocation.MyCommand.Module.ModuleBase
$Block = {
    $srv = $_.Name
    $rg  = $_.ResourceGroupName
    $sub = [regex]::Match($_.Id,'^\/subscriptions\/([0-9|a-f|-]{36})\/').Groups[1].Value
    $scr = $using:RemoteScript
    $dur = $using:DeliveryTimeout

    $VerbosePreference = $using:VerbosePreference
    dir (Join-Path $using:Root Private) *.ps1 | foreach {. $_.FullName}  # <-- dot-source our functions

    # load the Azure modules and set the Subscription
    $ProgressStatus = 'Loading Azure modules...'
    Initialize-AzModule -SubscriptionID $sub -Verbose:$false

    # run the user's script on the remote VM and show the output
    $ProgressStatus = 'Running remote command...'
    Invoke-RemoteScript -VMName $srv -RGName $rg -ScriptString $scr -Timeout $dur
}

# finally run the script and show the results
$out = Invoke-ForEachParallel $VM $Block Name $ThrottleLimit
$out | foreach {Receive-RemoteOutput $_.Output $_.VMName}

}