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