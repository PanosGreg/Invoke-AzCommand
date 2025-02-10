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
        $Chk = $_ | foreach {$_.GetType().Name -match 'PSVirtualMachine(List|ListStatus|InstanceView)?$'}
        $Chk -notcontains $false},
        ErrorMessage = 'Please provide a valid Azure VM object type'
    )]
    $VM,  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus] or [...PSVirtualMachineInstanceView]

    [Parameter(Mandatory,Position=1,ParameterSetName = 'ScriptBlock')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Args')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Params')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Container')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_ContainerPerVM')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Args_Container')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Params_Container')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Args_ContainerPerVM')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'Block_Params_ContainerPerVM')]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory,Position=1,ParameterSetName = 'ScriptFile')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Args')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Params')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Container')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_ContainerPerVM')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Args_Container')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Params_Container')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Args_ContainerPerVM')]
    [Parameter(Mandatory,Position=1,ParameterSetName = 'File_Params_ContainerPerVM')]
    [string]$ScriptFile,

    [Parameter(Mandatory,Position=2,ParameterSetName = 'File_Args')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'Block_Args')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'File_Args_Container')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'Block_Args_Container')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'File_Args_ContainerPerVM')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'Block_Args_ContainerPerVM')]
    [object[]]$ArgumentList,

    [Parameter(Mandatory,Position=2,ParameterSetName = 'File_Params')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'Block_Params')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'File_Params_Container')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'Block_Params_Container')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'File_Params_ContainerPerVM')]
    [Parameter(Mandatory,Position=2,ParameterSetName = 'Block_Params_ContainerPerVM')]
    [hashtable]$ParameterList,

    [Parameter(Mandatory,Position=3,ParameterSetName = 'File_Container')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'Block_Container')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'File_Args_Container')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'Block_Args_Container')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'File_Params_Container')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'Block_Params_Container')]
    [ValidateScript({
        $_.GetType().FullName -like '*Storage.ResourceModel.AzureStorageContainer'},
        ErrorMessage = 'Please provide a valid Azure Storage Container object'
    )]                  # <-- checks for [Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContainer]
    $StorageContainer,  #     without forcing the user to have the Az.Storage module loaded beforehand if he won't use this option

    [Parameter(Mandatory,Position=3,ParameterSetName = 'File_ContainerPerVM')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'Block_ContainerPerVM')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'File_Args_ContainerPerVM')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'Block_Args_ContainerPerVM')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'File_Params_ContainerPerVM')]
    [Parameter(Mandatory,Position=3,ParameterSetName = 'Block_Params_ContainerPerVM')]
    [switch]$UseContainerPerVM,

    [switch]$AsJob,
    [int]$ThrottleLimit    = 10,    # <-- maximum number of parallel threads used during execution, default is 10
    [int]$DeliveryTimeout  = 366,   # <-- time needed to run the Invoke-AzVMRunCommand, default is 5 minutes (ExecTime (5mins) plus ~1 minute for AzVMRunCommand to reach the Azure VM)
    [int]$ExecutionTimeout = 300,   # <-- this is the time needed to run the script on the remote VM
    [pscredential]$Credential
)
$ParamSetName = $PSCmdlet.ParameterSetName

# make sure the StorageContainer property exists
if ($ParamSetName -like '*ContainerPerVM*') {
    $Type = 'Microsoft.WindowsAzure.Commands.Common.Storage.ResourceModel.AzureStorageContainer'
    $ExpectedProperty = Test-ExpectedProperty $VM StorageContainer $Type -Verbose
    if (-not $ExpectedProperty) {
        Write-Warning 'When using "UseContainerPerVM" switch, please add the "StorageContainer" property on all VMs like so:'
        Write-Warning '$VM | Add-Member -NotePropertyMembers @{StorageContainer=$StorageContainer}'
        return
    }
}
## NOTE: this is not a good approach, I need to refactor that piece and find an alternative solution
##       Actually, simplify the code. Dont let the user have individual storage containers, just use one.

# if input was VM(s) of PSVirtualMachineInstanceView type, then refresh the variable
if (($VM | Get-Member)[0].TypeName -like '*PSVirtualMachineInstanceView') {
    Write-Verbose 'Input was PSVirtualMachineInstanceView type, refreshing the VM(s) without the status property.'
    if ($ParamSetName -like '*ContainerPerVM*') {
        $VM = $VM | foreach {
            $StCtr = $_.StorageContainer
            Get-AzVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Verbose:$false |
                Add-Member -NotePropertyMembers @{StorageContainer=$StCtr} -PassThru -Force
        }
    }
    else {
        $VM = $VM | foreach {Get-AzVM -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Verbose:$false}
    }
}

# make sure all VMs are on the same Azure subscription
$SameSub = Test-AzureSubscription $VM
if (-not $SameSub) {Write-Warning 'Please make sure all VMs are on the same subscription';return}

# run the command as a background job
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
if ($ParamSetName -like '*File*') {
    $File = Get-Item $ScriptFile -ErrorAction Stop                        # <-- this checks if the file exists
    if ($File.Length -gt 1MB) {throw "Scriptfile too big. $ScriptFile is $($File.Length) bytes"}
    try   {$ScriptText  = Get-Content $ScriptFile -Raw -ErrorAction Stop  # <-- this checks if the file is accessible
           $ScriptBlock = [scriptblock]::Create($ScriptText)}
    catch {throw $_}
}

# assemble the script that we'll run on the remote VM
$CmdId = (New-Guid).Guid.Substring(9,14)
$param = @{ScriptBlock = $ScriptBlock ; Timeout = $ExecutionTimeout ; CommandID = $CmdId}
if     ($ParamSetName -like '*Args*')   {$param.Add('ArgumentList',    $ArgumentList)}
elseif ($ParamSetName -like '*Params*') {$param.Add('ParameterList',   $ParameterList)}
if     ($Credential)                    {$param.Add('Credential',      $Credential)}
$RemoteScript = Write-RemoteScript @param

# create the scriptblock that we'll run in parallel
$Funcs = dir $MyInvocation.MyCommand.Module.FileList | where Directory -like *Private
$Block = {
    $vm  = $_
    $sub = [regex]::Match($vm.Id,'^\/subscriptions\/([0-9|a-f|-]{36})\/').Groups[1].Value

    # change the container details, if we output to Azure Storage
    $SB = [System.Text.StringBuilder]::new($using:RemoteScript)
    if ($using:ParamSetName -like '*Container*') {
        $OutTo = 'StorageContainer'
        [void]$SB.Replace('@STORAGE@',  $vm.StorageContainer.Context.StorageAccountName)
        [void]$SB.Replace('@CONTAINER@',$vm.StorageContainer.Name)
    }
    else {$OutTo = 'InvokeCommand'}
    [void]$SB.Replace('@OUTPUT@',$OutTo)
    
    $VerbosePreference = $using:VerbosePreference
    dir $using:Funcs | foreach {. $_.FullName} # <-- dot-source our functions

    # load the Azure modules and set the Subscription
    $ProgressStatus = 'Loading Azure modules...'
    Initialize-AzModule -SubscriptionID $sub

    # run the user's script on the remote VM and show the output
    $ProgressStatus = 'Running remote command...'
    Invoke-RemoteScript -VM $vm -ScriptString $SB.ToString() -Timeout $using:DeliveryTimeout
}

# add the storage container details on each VM object
if ($ParamSetName -like '*Container') {
    $VM | Add-Member -NotePropertyMembers @{StorageContainer=$StorageContainer} -Force
}  # NOTE: this will change the user's input object, so we'll need to remove the property once we're done

# run the script and get the results
$out = Invoke-ForEachParallel $VM $Block Name $ThrottleLimit
$out | foreach {Receive-RemoteOutput $_.Output $_.VM}

# revert back the change to the user's input object
if ($ParamSetName -like '*Container') {
    $VM | foreach {$_.psobject.Properties.Remove('StorageContainer')}
}

}