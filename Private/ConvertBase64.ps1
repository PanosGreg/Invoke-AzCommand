function ConvertTo-Base64String {
[OutputType([string])]
[CmdletBinding(DefaultParameterSetName = 'Scriptblock')]
param (
    [Parameter(Mandatory,Position=0,ParameterSetName = 'Function')]
    [System.Management.Automation.FunctionInfo[]]$FunctionInfo,

    [Parameter(Mandatory,Position=0,ParameterSetName = 'Scriptblock')]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory,Position=0,ParameterSetName = 'Argument')]
    [AllowNull()]
    [object[]]$ArgumentList,

    [Parameter(Mandatory,Position=0,ParameterSetName = 'Parameter')]
    [hashtable]$ParameterList,

    [Parameter(Mandatory,Position=0,ParameterSetName = 'Credential')]
    [pscredential]$Credential,

    [Parameter(Mandatory,Position=1,ParameterSetName = 'Credential')]
    [ValidateCount(32,32)]
    [Byte[]]$Key
)

if ($PSCmdlet.ParameterSetName -eq 'Function') {
    $AllFunctions = $FunctionInfo | foreach {
        $Definition = Remove-Comments $_.Definition
        "function {0} {{`n{1}`n}}" -f $_.Name,$Definition
    }
}
if ($PSCmdlet.ParameterSetName -eq 'Credential') {
    if ($Credential -eq [pscredential]::Empty) {$Cred = ' '}
    else {
        $User   = $Credential.UserName
        $Pass   = try {$Credential.GetNetworkCredential().Password} catch {$null}
        $SecStr = ConvertTo-SecureString -String "$User`n$Pass" -AsPlainText -Force
        $Cred   = $SecStr | ConvertFrom-SecureString -Key $Key  # <-- returns Encrypted String
    }
}

switch ($PSCmdlet.ParameterSetName) {
    Function    {$Text = $AllFunctions -join "`n"}
    Scriptblock {$Text = $ScriptBlock.ToString()}
    Argument    {$Text = [System.Management.Automation.PSSerializer]::Serialize($ArgumentList)}
    Parameter   {$Text = [System.Management.Automation.PSSerializer]::Serialize($ParameterList)}
    Credential  {$Text = $Cred}
}

$byte = [Text.Encoding]::UTF8.GetBytes($Text)
$b64  = [Convert]::ToBase64String($byte)

# Note: remember that a base64 string is 33% larger than the original string

Write-Output $b64
}

function ConvertFrom-Base64String {
[Alias('ConvertFrom-Base64Function')]
[Alias('ConvertFrom-Base64Scriptblock')]
[Alias('ConvertFrom-Base64Argument')]
[Alias('ConvertFrom-Base64Parameter')]
[Alias('ConvertFrom-Base64Credential')]
[cmdletbinding()]
[OutputType([string])]       # <-- for Function
[OutputType([scriptblock])]  # <-- for Scriptblock
[OutputType([object[]])]     # <-- for Argument
[OutputType([hashtable])]    # <-- for Parameter
[OutputType([securestring])] # <-- for Credential
param (
    [string]$InputString,
    [Byte[]]$Key    # <-- only needed if you're using the ConvertFrom-Base64Credential
)

$byte = [Convert]::FromBase64String($InputString)
$text = [Text.Encoding]::UTF8.GetString($byte)

$InputOption = ($MyInvocation.InvocationName).Split('-')[1].TrimStart('Base64')

if ($InputOption -eq 'Credential' -and $Key) {
    $SecStr = $text | ConvertTo-SecureString -Key $Key -ErrorAction Stop
    $Clear  = $SecStr | ConvertFrom-SecureString -AsPlainText -ErrorAction Stop
    $usr,$p = $Clear.Split("`n")
    $secp   = $pass | ConvertTo-SecureString -AsPlainText -Force -ErrorAction Stop
}

switch ($InputOption) {
    Function    {$out = $text}
    Scriptblock {$out = [scriptblock]::Create($text)}
    Argument    {$out = [System.Management.Automation.PSSerializer]::Deserialize($text)}
    Parameter   {$out = [System.Management.Automation.PSSerializer]::Deserialize($text) -as [hashtable]}
    Credential  {$out = [pscredential]::new($usr,$secp)}
    default     {Write-Warning 'Please use any of the aliases of this command';return}
}

Write-Output $out

}


## NOTE: PS5 does NOT have the -AsPlainText on the ConvertFrom-SecureString
##       so we need to do that part using .NET classes with a Binary String
##       on the remote code in Write-RemoteScript.