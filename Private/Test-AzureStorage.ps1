function Test-AzureStorage {
<#
.SYNOPSIS
    Checks if the computer has all the needed prerequisites to access an Azure Storage Container
    Namely this function checks for:
    - .NET Framework 4.7.2 or later is installed, if running on PS 5.x
    - The Az.Storage and Az.Accounts modules are installed
    - The server can access the https://xxx.blob.core.windows.net/ URL
    - The server can login to Azure using a Managed Identity
    And also adds TLS v1.2 to the list of supported security protocols
#>
[OutputType([bool])]
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$StorageAccountName,

    [Parameter(Mandatory)]
    [string]$StorageContainerName,

    [string[]]$Command = (
        'Connect-AzAccount',
        'Get-AzStorageContainer'
    )
)

$OriginalPreference = $VerbosePreference
$ProgressPreference = 'SilentlyContinue'

# set UseBasicParsing if PS v5
if ($PSVersionTable.PSVersion.Major -eq 5) {
    $PSDefaultParameterValues = @{
        'Invoke-WebRequest:UseBasicParsing' = $true
    }
}

# make sure TLS 1.2 is in the protocol list
$TLS  = [System.Net.SecurityProtocolType]::Tls12
$Prot = [System.Net.ServicePointManager]::SecurityProtocol
[System.Net.ServicePointManager]::SecurityProtocol = $Prot -bor $TLS

# helper function
function Get-DotnetVersion {
    $reg = 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    $rls = Get-ItemPropertyValue -LiteralPath $reg -Name Release
    switch ($rls) {
        { $_ -ge 533320 } { $version = '4.8.1' ; break }
        { $_ -ge 528040 } { $version = '4.8.0' ; break }
        { $_ -ge 461808 } { $version = '4.7.2' ; break }
        { $_ -ge 461308 } { $version = '4.7.1' ; break }
        { $_ -ge 460798 } { $version = '4.7.0' ; break }
        { $_ -ge 394802 } { $version = '4.6.2' ; break }
        { $_ -ge 394254 } { $version = '4.6.1' ; break }
        { $_ -ge 393295 } { $version = '4.6.0' ; break }
        { $_ -ge 379893 } { $version = '4.5.2' ; break }
        { $_ -ge 378675 } { $version = '4.5.1' ; break }
        { $_ -ge 378389 } { $version = '4.5.0' ; break }
        default           { $version = $null   ; break }
    }

    if ($version) {Write-Output $([version]$version)}
    else {
        Write-Warning '.NET Framework Version 4.5 or later is not detected.'
    }
} # Get-DotnetVersion

# check the dotnet version
$Ver = Get-DotnetVersion
if ($PSVersionTable.PSVersion.Major -eq 5) {  # <-- if PS 5.1 then we're running on .net framework
                                            #     (if it was PS 6+ then that would be .net core)
    $HasDotnet = $Ver -ge [version]'4.7.2'
    if (-not $HasDotnet) {
        Write-Verbose ".NET Version is $ver which is lower then the required 4.7.2"
    }
}

# check for the required commands
if ($HasDotnet) {
    $BooleanList = foreach ($cmd in $Command) {
        $VerbosePreference  = 'SilentlyContinue'  # <-- the get-command will also load the module, for which we don't want any verbose
        $HasCmd = [bool](Get-Command -Name $cmd -EA Ignore 3>$null)  # <-- I'm silencing warning stream because of the intelligent recommendation feature
        $VerbosePreference = $OriginalPreference
        $HasCmd
        if (-not $HasCmd) {Write-Verbose "Function $cmd was not found";break}
    }
    $HasCommands = $BooleanList -notcontains $false
    # NOTE: this will also load the relevant modules, namely Az.Accounts and Az.Storage
}
else {$HasCommands = $false}

# login to Azure
if ($HasCommands) {
    $CanLogin = (Connect-AzAccount -Identity -ErrorAction Ignore) -as [bool]
    if (-not $CanLogin) {
        Write-Verbose 'Could not login to Azure, make sure the computer has an Azure Identity attached to it'
    }
}
else {$CanLogin = $false}

# check for internet connectivity to Azure Blob Storage
if ($CanLogin) {
    $Ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount -Verbose:$false
    try   {Invoke-WebRequest -Uri $Ctx.BlobEndPoint -TimeoutSec 2 -ErrorAction Stop -Verbose:$false | Out-Null}
    catch {$Connection = $_}
    $Response   = $Connection.Exception.Response.StatusCode.ToString()
    $CanConnect = $Response -eq 'BadRequest'   # <-- this must return 400 (BadRequest)
                                               #     if it's ResponseTimeout or CouldNotResolve, then it's no good
    if (-not $CanConnect) {
        Write-Verbose "Could not connect to Azure Storage Account $($Ctx.BlobEndPoint)"
    }
}
else {$CanConnect = $false}

# check for the Azure Storage Container
if ($CanConnect) {
    try {
        $ConObj = Get-AzStorageContainer -Name $StorageContainerName -Context $Ctx -EA Stop -Verbose:$false
    }
    catch {}
    $HasContainer = $ConObj -as [bool]
    if (-not $HasContainer) {
        Write-Verbose "Could not retrieve the Azure Storage Container $StorageContainerName"
    }
}
else {$HasContainer = $false}

$TestResult = $HasDotnet -and $HasCommands -and $CanLogin -and $CanConnect -and $HasContainer

Write-Output $TestResult

}