function Write-RemoteScript {
[OutputType([string])]
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [scriptblock]$ScriptBlock,

    [AllowEmptyCollection()]
    [object[]]$ArgumentList,

    [int]$Timeout = 600 # <-- remote execution timeout period, default is 10 minutes (600 seconds)
)

$RemoteBlock = {
    function ConvertFrom-Base64String {
        [Alias('ConvertFrom-Base64Function')]
        [Alias('ConvertFrom-Base64Scriptblock')]
        [Alias('ConvertFrom-Base64Argument')]
        [CmdletBinding()] param([string]$InputString)
        $text   = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($InputString))
        $Option = ($MyInvocation.InvocationName).Split('-')[1].TrimStart('Base64')
        switch ($Option) {
            'Function'    {$text}
            'Scriptblock' {[scriptblock]::Create($text)}
            'Argument'    {[System.Management.Automation.PSSerializer]::Deserialize($text)}
        }
    }

    # placeholders for the base64 input strings
    $HelperFunction = ConvertFrom-Base64Function    '@FUNCTION@'   # <-- [string]
    $UsersCode      = ConvertFrom-Base64Scriptblock '@COMMAND@'    # <-- [scriptblock]
    $UsersArguments = ConvertFrom-Base64Argument    '@ARGUMENT@'   # <-- [object]
    $ExecTimeout    = '@TIMEOUT@' -as [int]
    
    # helper function for compressing the output, running the background job with runspaces
    Invoke-Expression -Command $HelperFunction

    # now run the remote block
    $Result = Start-RunspaceJob $UsersCode $UsersArguments $ExecTimeout

    # compress the output
    Write-Output (Get-CompressedOutput $Result)
} #remote block

# check if there's any user arguments
if ($ArgumentList.Count -eq 0) {
    $ArgumentList = '__No parameter was given for the remote command__'
}

# encode all input with Base64 encoding (the user's scriptblock,helper functions and any arguments given)
$Funcs  = Get-Item Function:\Compress-XmlString,Function:\Start-RunspaceJob,Function:\Get-CompressedOutput
$FunB64 = ConvertTo-Base64String -FunctionInfo $Funcs
$CmdB64 = ConvertTo-Base64String -ScriptBlock  $ScriptBlock
$ArgB64 = ConvertTo-Base64String -ArgumentList $ArgumentList

# Note: remember that a base64 string is 33% larger than the original string

# start building the remote command string
$SB = [System.Text.StringBuilder]::new($RemoteBlock.ToString())

# replace placeholders with the equivalent Base64 strings
[void]$SB.Replace('@FUNCTION@',$FunB64)  # <-- Helper functions
[void]$SB.Replace('@COMMAND@',$CmdB64)   # <-- User's scriptblock
[void]$SB.Replace('@ARGUMENT@',$ArgB64)  # <-- User's arguments
[void]$SB.Replace('@TIMEOUT@',$Timeout)  # <-- Execution timeout

Write-Output $SB.ToString()
}