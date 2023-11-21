function Import-FormatView {
<#
.SYNOPSIS
    Imports a few basic format data into the current session, to display objects
    with a default format.
.DESCRIPTION
    The issue here is that if you run a command inside a runspace, and collect
    the result. That result might be an object of any type, for example a WMI
    SMB Share object. Then if you try to show that in the current session it
    won't be shown with a specific format view, but instead all of its properties
    will be displayed, simply because in the current session you don't have the
    appropriate module loaded, for ex. the SmbShare module, and so the format
    view for that type of object is not loaded.
    This gap comes into play, when the data to be transferred across from the
    remote VM to the local machine through the Azure Run Command exceeds 4KB
    (that's the receive limit of the Azure VM Run Command), then I convert
    it to plain text (not objects), and show the default view of that.
    But since there is no view loaded, then the end-user gets all of the
    properties as text. While he expects to get the default view from the
    command he run.
    Something to note here, is that if the default view includes Enums,
    and those Enums come from the module, then only their respective Int
    value will be shown, and not the string from the enum.
    For example in Get-Volume, even though we load the Storage format data,
    some columns, like the HealthStatus or the DriveType, will only the
    equivalent enum value as Int, and not the actual Enum. Simply because
    we've not loaded the module but rather only the formatter.
    So we don't have the Enums in the current session.

    In all of the above cases, when the output exceeds 4kb, then it is
    advised that the end user should convert his output into string
    within his scriptblock if he wants to see the results with the 
    default formatted view as text.
#>
[OutputType([void])]
[cmdletbinding()]
param ()

$Root = 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules'
$Mods = '
    \Appx\Appx.format.ps1xml
    \BitLocker\BitLocker.Format.ps1xml
    \BitsTransfer\BitsTransfer.Format.ps1xml
    \BranchCache\BranchCache.format.ps1xml
    \DFSR\DFSR.Format.ps1xml
    \Dism\Dism.Format.ps1xml
    \DnsClient\DnsClientPSProvider.Format.ps1xml
    \DnsClient\DnsCmdlets.Format.ps1xml
    \NetAdapter\MSFT_NetAdapter.Format.ps1xml
    \NetTCPIP\Tcpip.Format.ps1xml
    \NetworkSwitchManager\NetworkSwitchManager.format.ps1xml
    \PnpDevice\PnpDevice.Format.ps1xml
    \PrintManagement\MSFT_Printer.format.ps1xml
    \PSDesiredStateConfiguration\PSDesiredStateConfiguration.format.ps1xml
    \PSScheduledJob\PSScheduledJob.Format.ps1xml
    \ScheduledTasks\MSFT_ScheduledTask.format.ps1xml
    \ServerManager\Feature.format.ps1xml
    \SmbShare\Smb.format.ps1xml
    \Storage\Storage.format.ps1xml
    \Wdac\Wdac.format.ps1xml
    \WindowsSearch\WindowsSearch.Format.ps1xml
    \WindowsUpdateProvider\MSFT_WUUpdate.format.ps1xml
'.Trim().Split("`n").ForEach({$_.Trim()})

$List = $Mods | foreach {
    $Path = Get-Item (Join-Path $Root $_) -EA 0
    if ([bool]$Path) {$Path.FullName}
}

if ($List.Count -ge 1) {Update-FormatData -AppendPath $List -Verbose:$false -EA Ignore}

}