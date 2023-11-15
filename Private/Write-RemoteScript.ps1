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

$RemoteBlock = {
    function ConvertFrom-Base64String {
        [Alias('ConvertFrom-Base64Function')]
        [Alias('ConvertFrom-Base64Scriptblock')]
        [Alias('ConvertFrom-Base64Argument')]
        [Alias('ConvertFrom-Base64Credential')]
        [CmdletBinding()] param([string]$InputString,[Byte[]]$Key)
        trap {return}  # <-- don't output anything if there's any error
        $text   = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($InputString))
        $Option = ($MyInvocation.InvocationName).Split('-')[1].TrimStart('Base64')
        if ($Key) {
            $SecStr = $text | ConvertTo-SecureString -Key $Key -ErrorAction Stop
            $BinStr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecStr)
            $Clear  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BinStr)
            $usr,$p = $Clear.Split("`n")
            $pass   = $p | ConvertTo-SecureString -AsPlainText -Force -EA Stop
        }
        switch ($Option) {
            Function    {$text}
            Scriptblock {[scriptblock]::Create($text)}
            Argument    {[System.Management.Automation.PSSerializer]::Deserialize($text)}
            Credential  {[pscredential]::new($usr,$pass)}
        }
    }

    # placeholders for the base64 input strings
    $ExecTimeout    = '@TIMEOUT@' -as [int]
    $InputType      = '@INPUT@'
    $UserContext    = '@CONTEXT@'
    $HelperFunction = ConvertFrom-Base64Function    '@FUNCTION@'   # <-- [string]
    $UsersCode      = ConvertFrom-Base64Scriptblock '@COMMAND@'    # <-- [scriptblock]
    $UserArgs       = ConvertFrom-Base64Argument    '@ARGUMENT@'   # <-- [object]

    # helper functions to a)compress the output, b)run the background job with runspaces, c)RunAs user
    Invoke-Expression -Command $HelperFunction

    # collect any user arguments
    if     ($InputType -eq 'WithNames') {$UserInput = @{ParameterList = $UserArgs -as [hashtable]}}
    elseif ($InputType -eq 'NoNames')   {$UserInput = @{ArgumentList  = $UserArgs}}
    elseif ($InputType -eq 'NoParams')  {$UserInput = $null}

    # now run the remote block
    if ($UserContext -eq 'SameUser') {
        $Result = Start-RunspaceJob -Scriptblock $UsersCode -Timeout $ExecTimeout @UserInput
    }
    elseif ($UserContext -eq 'OtherUser') {
        $Creds  = ConvertFrom-Base64Credential '@CREDENTIAL@' (Get-EncryptionKey FromIMDS) # <-- [pscredential]
        $Result = Start-RunspaceJob -Scriptblock $UsersCode -Timeout $ExecTimeout -RunAs $Creds @UserInput
    }

    # compress the output
    Write-Output (Get-CompressedOutput $Result)
} #remote block

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
$SB = [System.Text.StringBuilder]::new($RemoteBlock.ToString())

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