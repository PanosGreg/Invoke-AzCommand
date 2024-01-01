function Receive-AzureOutput {
<#
.SYNOPSIS
    It collects the output from a storage container
#>
[CmdletBinding()]
param (
    [string]$Blob,
    [string]$Container,

    [ValidateScript({
        $_.pstypenames -contains 'Microsoft.WindowsAzure.Commands.Storage.AzureStorageContext'
    })]
    $Context,

    $VM  # <-- we need this to pass it on to Receive-RemoteOutput again
)

$Dest = [System.IO.Path]::GetTempFileName()
try {
    $DownloadParams = @{
        Blob           = $Blob
        Container      = $Container
        Destination    = $Dest
        Context        = $Context
        Force          = $true
        Verbose        = $false
        ProgressAction = 'SilentlyContinue'
        ErrorAction    = 'Stop'
    }
    Get-AzStorageBlobContent @DownloadParams | Out-Null
}
catch {
    Write-Warning "Could not download file $Blob from Storage Container $Container"
    return
}

if (Test-Path $Dest) {
    $InputString = Get-Content $Dest -Raw -ErrorAction Stop
}
else {
    Write-Warning "Could not find file $Dest"
    return
}

Receive-RemoteOutput -InputString $InputString -FromVM $VM

try {
    $DeleteParams = @{
        Blob           = $Blob
        Container      = $Container
        Context        = $Context
        Force          = $true
        Verbose        = $false
        ProgressAction = 'SilentlyContinue'
        ErrorAction    = 'Stop'
    }
    Remove-AzStorageBlob -Blob $Blob -Container $Container -Context $Context -Force
    ## NOTE: maybe add a feature flag, on whether or not to keep the output file in Azure
}
catch {
    Write-Warning "Could not delete file $Blob from Storage Container $Container"
}

Remove-Item -Path $Dest -Force -Verbose:$false

}