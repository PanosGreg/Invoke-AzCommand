function Write-RemoteScript {
[OutputType([string])]
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [scriptblock]$ScriptBlock,

    [AllowEmptyCollection()]
    [object[]]$ArgumentList,

    [AllowNull()]
    [hashtable]$ParameterList,

    [int]$Timeout = 600 # <-- remote execution timeout period, default is 10 minutes (600 seconds)
)

$RemoteBlock = {
    function ConvertFrom-Base64String {
        [Alias('ConvertFrom-Base64Function')]
        [Alias('ConvertFrom-Base64Scriptblock')]
        [Alias('ConvertFrom-Base64Argument')]
        [Alias('ConvertFrom-Base64Parameter')]
        [CmdletBinding()] param([string]$InputString)
        trap {return}  # <-- don't output anything if there's any error
        $text   = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($InputString))
        $Option = ($MyInvocation.InvocationName).Split('-')[1].TrimStart('Base64')
        switch ($Option) {
            'Function'    {$text}
            'Scriptblock' {[scriptblock]::Create($text)}
            'Argument'    {[System.Management.Automation.PSSerializer]::Deserialize($text)}
            'Parameter'   {[System.Management.Automation.PSSerializer]::Deserialize($text) -as [hashtable]}
        }
    }

    # placeholders for the base64 input strings
    $ExecTimeout    = '@TIMEOUT@' -as [int]
    $InputType      = '@INPUT@'
    $HelperFunction = ConvertFrom-Base64Function    '@FUNCTION@'   # <-- [string]
    $UsersCode      = ConvertFrom-Base64Scriptblock '@COMMAND@'    # <-- [scriptblock]
    if ($InputType -eq 'WithNames') {
        $UserArgs = @{ParameterList = ConvertFrom-Base64Parameter '@ARGUMENT@'}  # <-- [hashtable]
    }
    elseif ($InputType -eq 'NoNames') {
        $UserArgs = @{ArgumentList  = ConvertFrom-Base64Argument  '@ARGUMENT@'}  # <-- [object]}
    }
    elseif ($InputType -eq 'NoParams') {$UserArgs = $null}
    
    # helper function for compressing the output, running the background job with runspaces
    Invoke-Expression -Command $HelperFunction

    # now run the remote block
    $Result = Start-RunspaceJob -Scriptblock $UsersCode -Timeout $ExecTimeout @UserArgs

    # compress the output
    Write-Output (Get-CompressedOutput $Result)
} #remote block

# check if there's any user arguments
if ($ParameterList.Keys.Count -gt 0) {
    $InputType = 'WithNames'
    $UserArgs = @{ParameterList = $ParameterList}
}
elseif ($ArgumentList.Count -gt 0) {
    $InputType = 'NoNames'
    $UserArgs = @{ArgumentList = $ArgumentList}
}
else {
    $InputType = 'NoParams'
    $UserArgs  = @{ArgumentList = $null}
}

# encode all input with Base64 encoding (the user's scriptblock,helper functions and any arguments given)
$Funcs  = Get-Item Function:\Compress-XmlString,Function:\Start-RunspaceJob,Function:\Get-CompressedOutput
$FunB64 = ConvertTo-Base64String -FunctionInfo $Funcs
$CmdB64 = ConvertTo-Base64String -ScriptBlock  $ScriptBlock
$ArgB64 = ConvertTo-Base64String @UserArgs

# Note: remember that a base64 string is 33% larger than the original string

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