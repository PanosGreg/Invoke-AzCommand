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

    [int]$Timeout = 600 # <-- remote execution timeout period, default is 10 minutes (600 seconds)
)

$RemoteBlock = {
    function ConvertFrom-Base64String {
        [Alias('ConvertFrom-Base64Function')]
        [Alias('ConvertFrom-Base64Scriptblock')]
        [Alias('ConvertFrom-Base64Argument')]
        [CmdletBinding()] param([string]$InputString)
        trap {return}  # <-- don't output anything if there's any error
        $text   = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($InputString))
        $Option = ($MyInvocation.InvocationName).Split('-')[1].TrimStart('Base64')
        switch ($Option) {
            'Function'    {$text}
            'Scriptblock' {[scriptblock]::Create($text)}
            'Argument'    {[System.Management.Automation.PSSerializer]::Deserialize($text)}
        }
    }

    # placeholders for the base64 input strings
    $ExecTimeout    = '@TIMEOUT@' -as [int]
    $InputType      = '@INPUT@'
    $HelperFunction = ConvertFrom-Base64Function    '@FUNCTION@'   # <-- [string]
    $UsersCode      = ConvertFrom-Base64Scriptblock '@COMMAND@'    # <-- [scriptblock]
    $UserArgs       = ConvertFrom-Base64Argument    '@ARGUMENT@'   # <-- [object]

    # helper function for compressing the output, running the background job with runspaces
    Invoke-Expression -Command $HelperFunction

    # now run the remote block
    if     ($InputType -eq 'WithNames') {$UserInput = @{ParameterList = $UserArgs -as [hashtable]}}
    elseif ($InputType -eq 'NoNames')   {$UserInput = @{ArgumentList  = $UserArgs}}
    elseif ($InputType -eq 'NoParams')  {$UserInput = $null}
    $Result = Start-RunspaceJob -Scriptblock $UsersCode -Timeout $ExecTimeout @UserInput

    # compress the output
    Write-Output (Get-CompressedOutput $Result)
} #remote block

# check if there's any user arguments
$ParamSetName = $PSCmdlet.ParameterSetName
if     ($ParamSetName -like '*Params') {$InputType = 'WithNames'}
elseif ($ParamSetName -like '*Args')   {$InputType = 'NoNames'}
else                                   {$InputType = 'NoParams'}
switch ($InputType) {
    'WithNames' {$UserArgs = @{ParameterList = $ParameterList}}
    'NoNames'   {$UserArgs = @{ArgumentList  = $ArgumentList}}
    'NoParams'  {$UserArgs = @{ArgumentList  = $null}}
}

# encode all input with Base64 encoding (the user's scriptblock,helper functions and any arguments given)
$Funcs  = Get-Item Function:\Compress-XmlString,Function:\Start-RunspaceJob,Function:\Get-CompressedOutput
$FunB64 = ConvertTo-Base64String -FunctionInfo $Funcs
$CmdB64 = ConvertTo-Base64String -ScriptBlock  $ScriptBlock
$ArgB64 = ConvertTo-Base64String @UserArgs

# start building the remote command string
$SB = [System.Text.StringBuilder]::new($RemoteBlock.ToString())

# replace placeholders with the equivalent Base64 strings
[void]$SB.Replace('@FUNCTION@',$FunB64)  # <-- Helper functions
[void]$SB.Replace('@COMMAND@',$CmdB64)   # <-- User's scriptblock
[void]$SB.Replace('@ARGUMENT@',$ArgB64)  # <-- User's arguments
[void]$SB.Replace('@TIMEOUT@',$Timeout)  # <-- Execution timeout
[void]$SB.Replace('@INPUT@',$InputType)  # <-- Unnamed arguments, named parameters or no parameters at all

Write-Output $SB.ToString()
}