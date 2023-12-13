function Write-RemoteScript {
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

    [int]$Timeout = 600, # <-- remote execution timeout period, default is 10 minutes (600 seconds)
    [pscredential]$Credential
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
$Funcs  = Get-RemoteHelperFunction
$FunB64 = ConvertTo-Base64String -FunctionInfo $Funcs
$CmdB64 = ConvertTo-Base64String -ScriptBlock  $ScriptBlock
$ArgB64 = ConvertTo-Base64String @UserArgs
$CreB64 = ConvertTo-Base64String @AltCreds

# start building the remote command string
$Root = $MyInvocation.MyCommand.Module.ModuleBase
$RemoteBlock = Get-Content -Path (Join-Path $Root Script RemoteScript.ps1) -Raw
$SB = [System.Text.StringBuilder]::new($RemoteBlock)

# replace placeholders with the equivalent Base64 strings
[void]$SB.Replace('@FUNCTION@',$FunB64)   # <-- Helper functions
[void]$SB.Replace('@COMMAND@',$CmdB64)    # <-- User's scriptblock
[void]$SB.Replace('@ARGUMENT@',$ArgB64)   # <-- User's arguments
[void]$SB.Replace('@TIMEOUT@',$Timeout)   # <-- Execution timeout
[void]$SB.Replace('@INPUT@',$InputType)   # <-- Unnamed arguments, named parameters or no parameters at all
[void]$SB.Replace('@CONTEXT@',$Context)   # <-- Use alternate credentials or not
[void]$SB.Replace('@CREDENTIAL@',$CreB64) # <-- Provided alternate credentials

Write-Output $SB.ToString()
}