function Receive-RemoteOutput {
[cmdletbinding()]
param (
    [string]$InputString,
    [string]$FromVM
)
$xml = Expand-XmlString $InputString -ErrorAction Stop -Verbose:$false

try   {$out = [Management.Automation.PSSerializer]::Deserialize($xml)}
catch {$out = $text}

# helper functions to add the VM Name as prefix in the Verbose or Warning messages
function script:InfoMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.InformationalRecord_Message
}
function script:GetMsg($Object,$Server=$FromVM) {
    '[{0}] {1}' -f $Server.ToUpper(),$Object.MessageData
}

$DSMA = 'Deserialized.System.Management.Automation'
$out | foreach {
    $Type = $_.pstypenames | Select-Object -First 1
    if     ($Type -eq "$DSMA.VerboseRecord")     {Write-Verbose (InfoMsg $_) -Verbose}
    elseif ($Type -eq "$DSMA.WarningRecord")     {Write-Warning (InfoMsg $_)}
    elseif ($Type -eq "$DSMA.InformationRecord") {Write-Host    (GetMsg $_)}
   #elseif ($Type -eq "$DSMA.ErrorRecord")       {$_ | Out-Default}  # <-- need to find a way to show Errors in Stream #2
    else                                         {Write-Output $_}
}

}


# only 2 options: Write-Error $ErrorRecord, $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord])
# so parse the remote deserialized error record and create a local one