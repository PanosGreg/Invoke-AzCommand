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
    [hashtable]$ParameterList
)

switch ($PSCmdlet.ParameterSetName) {
    'Function'    {$Text = ($FunctionInfo | foreach {"function {0} {{`n{1}`n}}" -f $_.Name,$_.Definition}) -join "`n"}
    'Scriptblock' {$Text = $ScriptBlock.ToString()}
    'Argument'    {$Text = [System.Management.Automation.PSSerializer]::Serialize($ArgumentList)}
    'Parameter'   {$Text = [System.Management.Automation.PSSerializer]::Serialize($ParameterList)}
}

$byte = [Text.Encoding]::UTF8.GetBytes($Text)
$b64  = [Convert]::ToBase64String($byte)

Write-Output $b64
}

function ConvertFrom-Base64String {
[Alias('ConvertFrom-Base64Function')]
[Alias('ConvertFrom-Base64Scriptblock')]
[Alias('ConvertFrom-Base64Argument')]
[Alias('ConvertFrom-Base64Parameter')]
[cmdletbinding()]
[OutputType([string])]       # <-- for Function
[OutputType([scriptblock])]  # <-- for Scriptblock
[OutputType([object[]])]     # <-- for Argument
[OutputType([hashtable])]    # <-- for Parameter
param (
    [string]$InputString
)

$byte = [Convert]::FromBase64String($InputString)
$text = [Text.Encoding]::UTF8.GetString($byte)

$InputOption = ($MyInvocation.InvocationName).Split('-')[1].TrimStart('Base64')

switch ($InputOption) {
    'Function'    {$out = $text}
    'Scriptblock' {$out = [scriptblock]::Create($text)}
    'Argument'    {$out = [System.Management.Automation.PSSerializer]::Deserialize($text)}
    'Parameter'   {$out = [System.Management.Automation.PSSerializer]::Deserialize($text) -as [hashtable]}
    default       {Write-Warning 'Please use any of the aliases of this command';return}
}

Write-Output $out

}