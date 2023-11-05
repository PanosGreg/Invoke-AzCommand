function Receive-RemoteOutput {
[cmdletbinding()]
param (
    [Parameter(Position=0)]
    [string]$InputString,
    
    [Parameter(Position=1)]
    [string]$FromVM
)

# decompress and deserialize the output
$Serializer = [System.Management.Automation.PSSerializer]
$xml = Expand-XmlString $InputString -ErrorAction Stop -Verbose:$false
try   {$out = $Serializer::Deserialize($xml) | where {$_.psobject}}  # <-- ignore any empty output
catch {$out = $xml}  # <-- if the output was too big (>4KB) then that would be plain text, not serialized

# helper functions to add the VM Name as prefix in the Verbose, Warning or Info messages
function script:InfoMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.InformationalRecord_Message
}
function script:GetMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.MessageData
}

# we'll enrich the output with extra properties
$Props = @{AzComputerName=$FromVM;AzUserName=(Get-AzContext).Account.Id}

$DSMA = 'Deserialized.System.Management.Automation'
$Hash = @{
    "$DSMA.VerboseRecord"     = {Write-Verbose (InfoMsg $_) -Verbose}
    "$DSMA.WarningRecord"     = {Write-Warning (InfoMsg $_)}
    "$DSMA.InformationRecord" = {Write-Host    (GetMsg $_)}
    "$DSMA.ErrorRecord"       = {$PSCmdlet.WriteError((Get-ErrorRecord $_ $Props))}
}
$out | foreach {
    $Type = $_.pstypenames.Where({$_},'First',1) -as [string]
    if ($Type -like "$DSMA.*Record") {. $Hash.$Type}
    else {
        Add-Member -Input $_ -NotePropertyMembers $Props -Force -PassThru
    }
}
}