function Write-RemoteScript {
<#
.SYNOPSIS
    It assembles the scriptblock (as a string) that will run on the remote VM
.NOTES
    There is also another part where we make changes to the remote script. Which is in the public
    function (Invoke-AzCommand). That part is about the output option (either direct or via azure storage container).
    I'm just pointing this out, cause the assembly of the remote script is split into 2 sections unfortunately,
    this function and that external part. See the Issues.txt on why this is done like that.
#>
[OutputType([string])]
[CmdletBinding(DefaultParameterSetName = 'Scriptblock')]
param (
    [Parameter(Mandatory,Position=0,ParameterSetName='Scriptblock')]
    [Parameter(Mandatory,Position=0,ParameterSetName='BlockAndArgs')]
    [Parameter(Mandatory,Position=0,ParameterSetName='BlockAndParams')]
    [scriptblock]$Scriptblock,

    [Parameter(Mandatory,Position=1,ParameterSetName='BlockAndArgs')]
    [AllowEmptyCollection()]
    [object[]]$ArgumentList,

    [Parameter(Mandatory,Position=1,ParameterSetName='BlockAndParams')]
    [AllowNull()]
    [hashtable]$ParameterList,

    [int]$Timeout = 300, # <-- remote execution timeout period, default is 5 minutes (300 seconds)
    [pscredential]$Credential,

    [ValidatePattern('^[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}$')]
    [string]$CommandID,

    [string]$TemplateFile = "$PSScriptRoot\..\Script\RemoteScript.ps1"
)

# check if there's any user arguments
switch -Wildcard ($PSCmdlet.ParameterSetName) {
    '*Params'  {$InputType='WithNames' ; $UserArgs=@{ParameterList = $ParameterList}}
    '*Args'    {$InputType='NoNames'   ; $UserArgs=@{ArgumentList  = $ArgumentList}}
    default    {$InputType='NoParams'  ; $UserArgs=@{ArgumentList  = $null}}
}

# check if there's any provided credentials
if ($Credential) {
    $Context  = 'OtherUser'
    $AltCreds = @{Credential = $Credential ; Key = Get-EncryptionKey}
}
else {
    $Context  = 'SameUser'
    $AltCreds = @{Credential = [pscredential]::Empty ; Key = [Byte[]]::new(32)}
}

# encode all input with Base64 encoding
# (the user's scriptblock,helper functions,alternate credentials and any arguments given)
$Funcs   = Get-RemoteHelperFunction
$FuncB64 = ConvertTo-Base64String -FunctionInfo $Funcs
$CmdB64  = ConvertTo-Base64String -ScriptBlock  $ScriptBlock
$ArgsB64 = ConvertTo-Base64String @UserArgs
$CredB64 = ConvertTo-Base64String @AltCreds

# start building the remote command string
$RemoteBlock = Get-Content -Path $TemplateFile -Raw
$SB = [System.Text.StringBuilder]::new($RemoteBlock)

# replace placeholders with the appropriate strings
[void]$SB.Replace('@FUNCTION@',$FuncB64)    # <-- Helper functions
[void]$SB.Replace('@COMMAND@',$CmdB64)      # <-- User's scriptblock
[void]$SB.Replace('@ARGUMENT@',$ArgsB64)    # <-- User's arguments
[void]$SB.Replace('@TIMEOUT@',$Timeout)     # <-- Execution timeout
[void]$SB.Replace('@INPUT@',$InputType)     # <-- Unnamed arguments, named parameters or no parameters at all
[void]$SB.Replace('@CONTEXT@',$Context)     # <-- Use alternate credentials or not
[void]$SB.Replace('@CREDENTIAL@',$CredB64)  # <-- Provided alternate credentials
[void]$SB.Replace('@COMMANDID@',$CommandID) # <-- The folder prefix for the Storage Container, and could also be used on other things in the future

Write-Output $SB.ToString()
}