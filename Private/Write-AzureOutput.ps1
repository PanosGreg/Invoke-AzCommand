function Write-AzureOutput {
<#
.SYNOPSIS
    It uploads the results into an Azure Storage Container and gives a small output
    that says where to download the results from.
#>
[OutputType([pscustomobject])]   # <-- if all goes well, then it outputs the object at the end of the function
[OutputType([object])]           # <-- if there's an issue, then it falls back to direct output which comes from the user's code
[CmdletBinding()]
param (
    $InputObject,
    [string]$AccountName,
    [string]$ContainerName,
    [string]$CommandID
)

$ProgressPreference = 'SilentlyContinue'

# check if computer has pre-requisites (ex. Az modules, internet connectivity, .Net framework, etc..)
$Test    = Test-AzureStorage -StorageAccountName $AccountName -StorageContainerName $ContainerName -Verbose 4>&1
$IsReady = $Test | where {$_ -is [bool]}
if ($IsReady -ne $true) {
    $msg = Write-Verbose 'The prerequisites for Azure Storage are not met, falling back to default output...' -Verbose 4>&1
    $err = $Test | where {$_ -is [System.Management.Automation.VerboseRecord]}
    Write-Output (Get-CompressedOutput $msg,$err,$InputObject)
    return
}

# save the results into a local file (once you serialize and compress the output)
$LocalFile = [System.IO.Path]::GetTempFileName()
$xml = [System.Management.Automation.PSSerializer]::Serialize($InputObject)  # <-- default depth is 1
$b64 = Compress-XmlString $xml
$b64 | Out-File -FilePath $LocalFile -Force

# generate a name for the blob
$AzureBlob = '{0}/{1}_output.txt' -f $CommandID,$env:COMPUTERNAME.ToLower()

# upload the file to the storage container
Connect-AzAccount -Identity -Verbose:$false 3>$null | Out-Null
$Ctx = New-AzStorageContext -StorageAccountName $AccountName -UseConnectedAccount -Verbose:$false 3>$null
try {
    $params = @{
        File        = $LocalFile
        Container   = $ContainerName
        Context     = $Ctx
        Blob        = $AzureBlob
        Force       = $true
        Verbose     = $false
        ErrorAction = 'Stop'
    }
    $Upload = Set-AzStorageBlobContent @params 3>$null
}
catch {
    $msg = Write-Verbose 'Coud not upload the file to Azure Storage, falling back to default output...' -Verbose 4>&1
    $err = Write-Verbose $_.Message -Verbose 4>&1
    Write-Output (Get-CompressedOutput $msg,$err,$InputObject)
    return  # <-- the finally block will still run, despite the return statement
}
finally {
    # clean up
    Remove-Item $LocalFile -Force -ErrorAction Ignore -Verbose:$false
}

# finally give some output saying where and what to download to get the results
$out = [pscustomobject] @{
    PSTypeName = 'InvokeAzCommand.StorageContainer'
    Account    = $AccountName
    Container  = $ContainerName
    Blob       = $AzureBlob
    ID         = $CommandID
    Type       = 'output'
}
Write-Output (Get-CompressedOutput $out)
}