function Remove-Comments {
<#
.SYNOPSIS
    Removes all single line comments, in-line comments and multi line comments from a scriptblock.
    It also removes any extra whitespaces as well as empty newlines.
.EXAMPLE
    $block = {
    # this is a line comment
    $env:COMPUTERNAME  # <-- end-of-line comment
    <#  mult-line
        comment
    # >
    Write-Output <# in-line comment # > 'aaa'
    #the following line is an empty line

    $a      =  'aa'   # this is a line with extra spaces
    }
    $block.Invoke()
    $block.ToString
    Remove-Comments -Scriptblock $block

    # see the difference in byte size (268 vs 52 bytes)
    $block.ToString().Length
    (Remove-Comments $block).Length

    # this is a showcase of how the remove-comments function works
    # please remove the space between the # and > in the example, as-in # >
    # in line 6 and in line 7, before you give it a try.
#>
[OutputType([String])]
[CmdletBinding(DefaultParameterSetName='Script')]
param (
    [Parameter(Mandatory,Position=0,ParameterSetName='Script',ValueFromPipeline=$true)]
    [Scriptblock]$Scriptblock,
    [Parameter(Mandatory,Position=0,ParameterSetName='Text',ValueFromPipeline=$true)]
    [string]$Textblock
)
if ($PSCmdlet.ParameterSetName -eq 'Script') {$BlockString = $ScriptBlock.ToString()}
if ($PSCmdlet.ParameterSetName -eq 'Text')   {$BlockString = $TextBlock
                                              $ScriptBlock = [scriptblock]::Create($TextBlock)}
$Parser        = [System.Management.Automation.PSParser]::Tokenize($ScriptBlock,[Ref]$Null)
$Tokens        = $Parser.Where({$_.Type -ne 'Comment'})
$StringBuilder = [System.Text.StringBuilder]::new()
$CurrentColumn = 1
$NewlineCount  = 0
foreach($CurrentToken in $Tokens) {
    # Now output the token
    if(($CurrentToken.Type -eq 'NewLine') -or ($CurrentToken.Type -eq 'LineContinuation')) {
        $CurrentColumn = 1
        # Only insert a single newline. Sequential newlines are ignored in order to save space.
        if ($NewlineCount -eq 0) {
            $StringBuilder.AppendLine() | Out-Null
        }
        $NewlineCount++
    }
    else {
        $NewlineCount = 0
        # Do any indenting
        if($CurrentColumn -lt $CurrentToken.StartColumn) {
            # Insert a single space in between tokens on the same line. Extraneous whiltespace is ignored.
            if ($CurrentColumn -ne 1) {
                $StringBuilder.Append(' ') | Out-Null
            }
        }
        # See where the token ends
        $CurrentTokenEnd = $CurrentToken.Start + $CurrentToken.Length - 1
        # Handle the line numbering for multi-line strings
        if(($CurrentToken.Type -eq 'String') -and ($CurrentToken.EndLine -gt $CurrentToken.StartLine)) {
            $LineCounter = $CurrentToken.StartLine
            $StringLines = $(-join $BlockString[$CurrentToken.Start..$CurrentTokenEnd] -split '`r`n')
            foreach($StringLine in $StringLines) {
                $StringBuilder.Append($StringLine) | Out-Null
                $LineCounter++
            }
        }
        # Write out a regular token
        else {
            $StringBuilder.Append((-join $BlockString[$CurrentToken.Start..$CurrentTokenEnd])) | Out-Null
        }
        # Update our position in the column
        $CurrentColumn = $CurrentToken.EndColumn
    }
}
Write-Output $StringBuilder.ToString()
}