function Get-EncryptionKey {
<#
.SYNOPSIS
    Returns a 32-byte array
.DESCRIPTION
    First it gets the Azure Subscription ID.
    The ID is collected from either the Instance Metadata Service or from
    the PowerShell command (Get-AzContext). The ID will be used to generate
    an encryption key. The subscription id gets hashed with SHA256 which returns
    an array of 32 bytes long. And that hash will be used as the encryption key.

    If the ID is retrieved from IMDS, that means the computer must be an Azure VM.
    If the ID is retrieved from Local, that means you need to have the Azure modules
    and also be logged in to Azure. (so it can be any computer)
#>
[cmdletbinding()]
param (
    [ValidateSet('FromLocal','FromIMDS')]
    [string]$Source = 'FromLocal',

    [switch]$AsHex
)

# get the Azure Subscription ID
if ($Source -eq 'FromLocal') {
    # need to handle the verbose preference manually
    # cause Import-Module doesn't respect it when it loads the Azure modules
    $Orig = $Global:VerbosePreference
    $Global:VerbosePreference = 'SilentlyContinue'
    Import-Module Az.Accounts -ErrorAction Stop -Verbose:$false
    
    # get the Azure Subscription ID
    $ctx = Get-AzContext -RefreshContextFromTokenCache -ListAvailable:$false -Verbose:$false 3>$null
    $id  = $ctx.Subscription.Id

    $Global:VerbosePreference = $Orig
}
elseif ($Source -eq 'FromIMDS') {
    # disable proxy
    $NoProxy          = [System.Net.WebProxy]::new()  # <-- set null proxy
    $WebSession       = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $WebSession.Proxy = $NoProxy

    # get the supported metadata versions and the instance metadata
    $PSDefaultParameterValues['Invoke-RestMethod:WebSession'] = $WebSession
    $PSDefaultParameterValues['Invoke-RestMethod:Headers']    = @{Metadata='true'}
    $PSDefaultParameterValues['Invoke-RestMethod:TimeoutSec'] = 3
    $UrlVer = 'http://169.254.169.254/metadata/versions'
    $Ver    = (Invoke-RestMethod -Method Get -Uri $UrlVer).apiVersions[-1]
    $UrlIns = "http://169.254.169.254/metadata/instance?api-version=$Ver"
    $Meta   = (Invoke-RestMethod -Method GET -Uri $UrlIns).compute

    $id = $Meta.subscriptionId
}

# convert the id into a byte array
$Bytes = [System.Text.Encoding]::ASCII.GetBytes($id)

# Hash the byte array
$Sha32 = [System.Security.Cryptography.SHA256]::Create()
$Hash  = $Sha32.ComputeHash($Bytes)  # <-- 32 Byte length

# show the output
if ($AsHex) {($Hash | foreach {$_.ToString('x2')}) -join ''}
else        {Write-Output $Hash}

# Note: 
# In PS7 they've introduced a builtin method to convert a string to hex
# [System.Convert]::ToHexString()
# But it's not available on PS v5.
# Remember this function will run both locally (PS7) and on the remote VM which has PS5.

}