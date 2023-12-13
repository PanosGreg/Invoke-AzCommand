function Get-ErrorRecord {
<#
.SYNOPSIS
    Re-creates a deserialized error record
#>
[OutputType([System.Management.Automation.ErrorRecord])]
[CmdletBinding()]
param (
    [Parameter(Mandatory,ValueFromPipeline)]
    [ValidateScript({$_.pstypenames[0] -like 'Deserialized.*.ErrorRecord'})]
    $ErrorObject,

    [hashtable]$ExtraProperties
)

function Get-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline,Mandatory)]
        $ErrorRecord
    )
    $msg = $null
    if ($ErrorRecord.psobject.Properties['InnerException'] -and
        $ErrorRecord.InnerException) {
            $msg = $ErrorRecord.InnerException.Message
            Get-ErrorMessage $ErrorRecord.InnerException
    }
    if ($ErrorRecord.psobject.Properties['SerializedRemoteException'] -and
        $ErrorRecord.SerializedRemoteException) {
            $msg = $ErrorRecord.SerializedRemoteException.Message
            Get-ErrorMessage $ErrorRecord.SerializedRemoteException
    }
    if ($ErrorRecord.psobject.Properties['Exception'] -and
        $ErrorRecord.Exception) {
            $msg = $ErrorRecord.Exception.Message
            Get-ErrorMessage $ErrorRecord.Exception
    }
    $MsgIsEmpty = [string]::IsNullOrWhiteSpace($msg)
    if (-not $MsgIsEmpty) {Write-Output $msg}
} # function - Get-ErrorMessage

$Messages = Get-ErrorMessage -ErrorRecord $ErrorObject
[System.Array]::Reverse($Messages)

$Command = @(
    'System.Management.Automation'           # <-- ErrorCategory, ErrorRecord, InvocationInfo
    'System.Management.Automation.Language'  # <-- ScriptPosition, ScriptExtent
    'System.Reflection'                      # <-- BindingFlags
) | foreach {"using namespace $_"}
. ([scriptblock]::Create(($command -join "`n")))

$msg  = $Messages -join "`n"
$cat  = [ErrorCategory]$ErrorObject.ErrorCategory_Category
$id   = $ErrorObject.FullyQualifiedErrorId
$obj  = $ErrorObject.TargetObject

# try to find the public type of the exception
foreach ($ErrorType in $ErrorObject.Exception.pstypenames) {
    $type = $ErrorType -replace '^Deserialized\.' -as [type]
    if ($null -ne $type) {break}
}
$exc  = $type::new($msg)
$rec  = [ErrorRecord]::new($exc,$id,$cat,$obj)
$rec.CategoryInfo.Activity = $ErrorObject.ErrorCategory_Activity

# get the total number for all binding flags, we'll need this to get the fields through reflection
$AllFlags  = [System.Enum]::GetValues([BindingFlags]) -join ','
$BindFlags = ([BindingFlags]$AllFlags).value__

# change the stacktrace - to do this we need to use reflection cause it's a ReadOnly property
$StackField = $rec.GetType().GetField('_scriptStackTrace',$BindFlags)
$StackField.SetValue($rec,$ErrorObject.ErrorDetails_ScriptStackTrace)

# create a new invocation from the deserialized one
$_ScriptName     = $ErrorObject.InvocationInfo.ScriptName
$_LineNumber     = $ErrorObject.InvocationInfo.ScriptLineNumber
$_OffsetInLine   = $ErrorObject.InvocationInfo.OffsetInLine
$_Line           = $ErrorObject.InvocationInfo.Line
#$_CommandInfo    = Get-Command $ErrorObject.InvocationInfo.MyCommand  # <-- PROBLEM - this will error out if the remote cmd is not found locally
$_CommandInfo    = Get-Command Get-ErrorRecord   # <-- it doesn't matter anyway, since this gets overridden from Receive-RemoteOutput
$StartPosition   = [ScriptPosition]::new($_ScriptName,$_LineNumber,$_OffsetInLine,$_Line)
$EndPosition     = [ScriptPosition]::new($_ScriptName,$_LineNumber,$_OffsetInLine+$_Line.Length,$_Line)
$ScriptExtent    = [ScriptExtent]::new($StartPosition,$EndPosition)
$NewInvocation   = [InvocationInfo]::Create($_CommandInfo,$ScriptExtent)
$InvocaNameField = $NewInvocation.GetType().GetField('_invocationName',$BindFlags)
$InvocaNameField.SetValue($NewInvocation,$_CommandInfo.Name)

# change the invocation info - again this needs to be done with reflection
$InvocationField = $rec.GetType().GetField('_invocationInfo',$BindFlags)
$InvocationField.SetValue($rec,$NewInvocation)

# enrich the error record with extra properties, if given any
if ($ExtraProperties) {
    $rec | Add-Member -NotePropertyMembers $ExtraProperties -Force
}

Write-Output $rec
}