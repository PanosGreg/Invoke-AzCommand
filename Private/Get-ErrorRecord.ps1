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

$msg  = $Messages -join "`n"
$cat  = [System.Management.Automation.ErrorCategory]$ErrorObject.ErrorCategory_Category
$id   = $ErrorObject.FullyQualifiedErrorId
$obj  = $ErrorObject.TargetObject
$type = $ErrorObject.Exception.pstypenames[0] -replace '^Deserialized\.' -as [type]
$exc  = $type::new($msg)
$rec  = [System.Management.Automation.ErrorRecord]::new($exc,$id,$cat,$obj)
Write-Output $rec
}