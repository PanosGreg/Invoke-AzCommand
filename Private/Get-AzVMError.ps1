function Get-AzVMError {
[OutputType([string])]
[cmdletbinding()]
param (
    [Parameter(Mandatory,Position=0)]
    [ValidateScript({
        ($_.Exception | Get-Member).TypeName[0] -like '*ComputeCloudException'
    })]
    [System.Management.Automation.ErrorRecord]$AzVMError,

    [Parameter(Position=1)]
    [string]$VMName = $env:COMPUTERNAME
)

$ErrType = $AzVMError.Exception.pstypenames[0] -as [string]
#$Trace   = $AzVMError.Exception.InnerException.StackTrace
#$ErrSrc  = [regex]::Match($Trace,'at (.+VMRunCommand)').Groups[1].Value
$ErrHttp = $AzVMError.Exception.InnerException.Response.StatusCode.value__
$ErrText = $AzVMError.Exception.Message.Split("`n")
$ErrStatus,$ErrMsg = $ErrText | foreach {
    $Rgx = [regex]::Match($_,'^Error(Code|Message): (.+)')
    if ($Rgx.Success) {$Rgx.Groups[2].Value}
}

$obj = [pscustomobject]@{
    PSTypeName   = 'AZCommand.AZVMError'
    ErrorFrom    = $VMName.ToUpper()
    ErrorType    = $ErrType
    ErrorSource  = 'Invoke-AzVMRunCommand'
    ErrorHTTP    = $ErrHttp
    ErrorStatus  = $ErrStatus
    ErrorMessage = $ErrMsg
}

$ToString = {
@"

ErrorFrom:`t$($this.ErrorFrom)
ErrorType:`t$($this.ErrorType)
ErrorSource:`t$($this.ErrorSource)
ErrorHTTP:`t$($this.ErrorHTTP)
ErrorStatus:`t$($this.ErrorStatus)
ErrorMessage:`t$($this.ErrorMessage)
"@
}
$obj | Add-Member -MemberType ScriptMethod -Name ToString -Value $ToString -Force

Write-Output $obj
}