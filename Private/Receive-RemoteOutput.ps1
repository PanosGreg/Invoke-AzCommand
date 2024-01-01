function Receive-RemoteOutput {
[cmdletbinding()]
param (
    [Parameter(Mandatory,Position=0)]
    [string]$InputString,
 
    [Parameter(Mandatory,Position=1)]
    [ValidateScript({
        $Chk = $_ | foreach {$_.GetType().Name -match 'PSVirtualMachine(List|ListStatus)?$'}
        $Chk -notcontains $false},
        ErrorMessage = 'Please provide a valid Azure VM object type'
    )]
    $FromVM  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus]
)

. ([scriptblock]::Create('using namespace System.Management.Automation'))  # <-- PSSerializer,PSPropertySet,PSMemberInfo

$VMName = $FromVM.Name

# decompress and deserialize the output
$xml = Expand-XmlString $InputString -ErrorAction Stop -Verbose:$false
try   {$out = [PSSerializer]::Deserialize($xml)}
catch {$out = $xml}  # <-- if the output was too big (>4KB) then that would be plain text, not serialized

# helper functions to add the VM Name as prefix in the Verbose, Warning or Info messages
function script:GetInfoMsg($Object,$Server=$VMName) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.InformationalRecord_Message
}
function script:GetMsgData($Object,$Server=$VMName) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.MessageData
}

# we'll enrich the output with extra properties
$AzProps = @{
    AzComputerName = $VMName.ToUpper()
    AzUserName     = (Get-AzContext).Account.Id
}

$DSMA = 'Deserialized.System.Management.Automation'
$Hash = @{
    "$DSMA.VerboseRecord"     = {Write-Verbose (GetInfoMsg $_) -Verbose}
    "$DSMA.WarningRecord"     = {Write-Warning (GetInfoMsg $_)}
    "$DSMA.InformationRecord" = {Write-Host    (GetMsgData $_)}
    "$DSMA.ErrorRecord"       = {$PSCmdlet.WriteError((Get-ErrorRecord $_ $AzProps))}
}
$out | where {$_.psobject} | foreach {  # <-- I've added the Where {} to ignore any $null output
    $Types = $_.pstypenames
    if     ($Types[0] -like  "$DSMA.*Record") {. $Hash[$Types[0]]}       # <-- write verbose/warning/info/error
    elseif ($Types[0] -eq 'Deserialized.InvokeAzCommand.StorageContainer') {
        $Ctx = $FromVM.StorageContainer.Context
        Receive-AzureOutput -Blob $_.Blob -Container $_.Container -Context $Ctx -VM $FromVM
    }
    elseif ($Types -contains "$DSMA.PSCustomObject") {                   # <-- add extra properties but don't show them by default
        $prop = [string[]]$_.psobject.Properties.Name
        $pset = [PSPropertySet]::new('DefaultDisplayPropertySet',$prop)
        $Memb = [PSMemberInfo[]]@($pset)
        $_ | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $Memb -Force
        # NOTE: the PSStandardMembers member set does not get serialized properly, so even if the user had a default display set in his scriptblock
        #       the resulting deserialized pscustomobject won't show it. Hance why it doesn't matter if we overrwrite the PSStandardMembers
        $_ | Add-Member -NotePropertyMembers $AzProps -Force -PassThru   # <-- and then add our custom properties, which won't be part of the default set
    }
    else {                                                               # <-- if not PSCustomObject, then just add the properties as-is
        $_ | Add-Member -NotePropertyMembers $AzProps -Force -PassThru
    }
}
}