function Get-RemoteHelperFunction {
<#
.SYNOPSIS
    Helper functions that are sent over to the remote VM and are needed for the remote command.
    These are used in the Write-RemoteScript function.
#>
param (
    $FunctionName = (
        'Compress-XmlString',
        'Start-RunspaceJob',
        'Get-CompressedOutput',
        'Invoke-WithImpersonation',
        'Get-EncryptionKey'
    )
)
$FunctionList = $FunctionName | foreach {"Function:\$_"}
Get-Item $FunctionList
}