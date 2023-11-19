function Write-ExtraInfo([string]$Message){
<#
.SYNOPSIS
    This function is used to provide some more information for the next Pester test.
    It adds an arrow which points to a short message.
    Since this function is used within the Pester logic, I'm using Write-Host to show
    the message to the console. Otherwise it won't be shown if I use Write-Output.
#>
    $DarkCyan = [char]27 + '[38;2;0;153;153m'
    $Default  = [char]27 + '[0m'
    $Italic   = [char]27 + '[3m'
    $Ident    = ' '*4
    Write-Host "$Ident$DarkCyan┌──►$Italic$Message$Default"    
}