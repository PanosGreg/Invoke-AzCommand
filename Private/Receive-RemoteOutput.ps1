function Receive-RemoteOutput {
[cmdletbinding()]
param (
    [Parameter(Position=0)]
    [string]$InputString,
    
    [Parameter(Position=1)]
    [string]$FromVM
)
$xml = Expand-XmlString $InputString -ErrorAction Stop -Verbose:$false

try   {$out = [System.Management.Automation.PSSerializer]::Deserialize($xml)}
catch {$out = $xml}    # <-- if the output was too big (>4KB) then that would be plain text, not serialized

# helper functions to add the VM Name as prefix in the Verbose, Warning or Info messages
function script:InfoMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.InformationalRecord_Message
}
function script:GetMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.MessageData
}

$DSMA = 'Deserialized.System.Management.Automation'
$Hash = @{
    "$DSMA.VerboseRecord"     = {Write-Verbose (InfoMsg $_) -Verbose}
    "$DSMA.WarningRecord"     = {Write-Warning (InfoMsg $_)}
    "$DSMA.InformationRecord" = {Write-Host    (GetMsg $_)}
    "$DSMA.ErrorRecord"       = {$PSCmdlet.WriteError((Get-ErrorRecord $_))}
}
$out | foreach {
    $Type = $_.pstypenames.Where({$_},'First',1) -as [string]
    if ($Type -like "$DSMA.*Record") {. $Hash.$Type}
    else                             {Write-Output $_}
}
}