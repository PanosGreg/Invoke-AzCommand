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
    Invoke-AzCommand $All {Write-Verbose 'vvv' -Verbose;Write-Warning 'www';Write-Output 'aaa'}
    # we get different streams in the output
.EXAMPLE
    $All = Get-AzVM ; $file = 'C:\Temp\MyScript.ps1'
    Invoke-AzCommand $All $file
    # we run a script file instead of a scriptblock on the remote VM
.EXAMPLE
    $All = Get-AzVM
    Invoke-AzCommand $All {param($Size,$Name) "$Name - $Size"} -Param @{Name='John';Size='XL'}
    # we pass named parameters instead of positional
.EXAMPLE
    # get a running Azure Linux VM (not Windows) or a Windows VM that is stopped (not running)
    Invoke-AzCommand $LinuxVM {$env:ComputerName}
    Invoke-AzCommand $StoppedVM {$env:ComputerName}
    # it returns human readable error messages with all the important details
.EXAMPLE
    Invoke-AzCommand $VM {Get-Service Non-Existing-Service}
    # it returns the actual error message from the remote VM as-if it was local
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

    [int]$ThrottleLimit    = 10,    # <-- maximum number of parallel threads used during execution, default is 10
    [int]$DeliveryTimeout  = 666,   # <-- time needed to run the Invoke-AzVMRunCommand, default 10+ minutes (ExecTime plus 1+ minute for AzVMRunCommand to reach the Azure VM)
    [int]$ExecutionTimeout = 600    # <-- this is the time needed to run the script on the remote VM
)

# get the user's script & arguments and also our functions that we'll use inside the foreach parallel
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

$RemoteScript  = Write-RemoteScript $ScriptBlock @UserArgs -Timeout $ExecutionTimeout
$ModuleFolder  = $MyInvocation.MyCommand.Module.ModuleBase
$ScriptsToLoad = 'Invoke-RemoteScript,Initialize-AzModule,Receive-RemoteOutput,Expand-XmlString,Get-AzVMError'
$ScriptList    = $ScriptsToLoad.Split(',') | foreach {Join-Path $ModuleFolder "\Private\$_.ps1"}

# create the scriptblock that we'll run in parallel
$Block = {
    $srv = $_.Name
    $rg  = $_.ResourceGroupName
    $sub = [regex]::Match($_.Id,'^\/subscriptions\/([0-9|a-f|-]{36})\/').Groups[1].Value
    $scr = $using:RemoteScript
    $dur = $using:DeliveryTimeout

    $VerbosePreference = $using:VerbosePreference
    $using:ScriptList | foreach {. $_}  # <-- dot-source our helper functions

    # load the Azure modules and set the Subscription
    $ProgressStatus = 'Loading Azure modules...'
    Initialize-AzModule -SubscriptionID $sub -Verbose:$false

    # run the user's script on the remote VM and show the output
    $ProgressStatus = 'Running remote command...'
    Invoke-RemoteScript -VMName $srv -RGName $rg -ScriptString $scr -Timeout $dur
}

# finally run the script and show the results
$out = Invoke-ForEachParallel $VM $Block Name $ThrottleLimit
$out | foreach {Receive-RemoteOutput $_.Output $_.VMName | where {$_.psobject}}

}