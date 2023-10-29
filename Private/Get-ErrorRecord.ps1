function Get-ErrorRecord {
<#
.SYNOPSIS
    Re-creates a deserialized error record
#>
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline)]
    $ErrorObject = $Global:Error[0]
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

    $IsEmpty = [string]::IsNullOrWhiteSpace($msg)
    if (-not $IsEmpty) {Write-Output $msg}
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
$type = $ErrorObject.Exception.pstypenames[0] -replace '^Deserialized\.' -as [type]
$exc  = $type::new($msg)
$rec  = [ErrorRecord]::new($exc,$id,$cat,$obj)
$rec.CategoryInfo.Activity = $ErrorObject.ErrorCategory_Activity

# change the stacktrace - to do this we need to use reflection cause it's a ReadOnly property
$StackField = $rec.GetType().GetField('_scriptStackTrace',[BindingFlags]50855807)
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
$InvocaNameField = $NewInvocation.GetType().GetField('_invocationName',50855807)
$InvocaNameField.SetValue($NewInvocation,$_CommandInfo.Name)

# change the invocation info - again this needs to be done with reflection
$InvocationField = $rec.GetType().GetField('_invocationInfo',[BindingFlags]50855807)
$InvocationField.SetValue($rec,$NewInvocation)

Write-Output $rec
}


<#
# To get the Binding Flags total number:
$AllFlags = @(
    'Default'
    'IgnoreCase'
    'DeclaredOnly'
    'Instance'
    'Static'
    'Public'
    'NonPublic'
    'FlattenHierarchy'
    'InvokeMethod'
    'CreateInstance'
    'GetField'
    'SetField'
    'GetProperty'
    'SetProperty'
    'PutDispProperty'
    'PutRefDispProperty'
    'ExactBinding'
    'SuppressChangeType'
    'OptionalParamBinding'
    'IgnoreReturn'
    'DoNotWrapExceptions'
) -join ','
([System.Reflection.BindingFlags]$AllFlags).value__
#>