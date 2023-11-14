function Receive-RemoteOutput {
[cmdletbinding()]
param (
    [Parameter(Position=0)]
    [string]$InputString,
    
    [Parameter(Position=1)]
    [string]$FromVM
)

. ([scriptblock]::Create('using namespace System.Management.Automation'))  # <-- PSSerializer,PSPropertySet,PSMemberInfo

# decompress and deserialize the output
$xml = Expand-XmlString $InputString -ErrorAction Stop -Verbose:$false
try   {$out = [PSSerializer]::Deserialize($xml) | where {$_.psobject}}  # <-- ignore any empty output
catch {$out = $xml}  # <-- if the output was too big (>4KB) then that would be plain text, not serialized

# helper functions to add the VM Name as prefix in the Verbose, Warning or Info messages
function script:GetInfoMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.InformationalRecord_Message
}
function script:GetMsgData($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.MessageData
}

# we'll enrich the output with extra properties
$AzProps = @{
    AzComputerName = $FromVM.ToUpper()
    AzUserName     = (Get-AzContext).Account.Id
}

$DSMA = 'Deserialized.System.Management.Automation'
$Hash = @{
    "$DSMA.VerboseRecord"     = {Write-Verbose (GetInfoMsg $_) -Verbose}
    "$DSMA.WarningRecord"     = {Write-Warning (GetInfoMsg $_)}
    "$DSMA.InformationRecord" = {Write-Host    (GetMsgData $_)}
    "$DSMA.ErrorRecord"       = {$PSCmdlet.WriteError((Get-ErrorRecord $_ $AzProps))}
}
$out | foreach {
    $Types = $_.pstypenames
    if     ($Types[0] -like  "$DSMA.*Record") {. $Hash[$Types[0]]}       # <-- write verbose/warning/info/error
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