function Test-PesterRequirement {
<#
.SYNOPSIS
    Checks all the pre-requisites so that Invoke-AzCommand can be tested
#>
[OutputType([bool])]
[CmdletBinding()]
param (
    [AllowEmptyCollection()]
    $UserInput
)

$Success = $true
$VM = $UserInput   # <-- change the var name of the input to VM

if ($Success) {
    if ($null -eq $VM) {
        Write-Warning 'Please provide some Azure VMs to test against'
        $Success = $false
    }
}

## check the user input, the variable name must be "VM"
#if ($Success) {
#    $HasInput = $PesterInput.ContainsKey('VM')
#    if (-not $HasInput) {
#        Write-Warning 'Could not find the $VM variable'
#        $Success = $false
#    }
#}

# check the VM variable type
if ($Success) {
    $IsType = $VM | foreach {$_.GetType().Name -match 'PSVirtualMachine(List|ListStatus)?$'}
    $HasCorrectType = $IsType -notcontains $false
    if (-not $HasCorrectType) {
        Write-Warning 'Please provide valid Azure VM object type'
        $Success = $false
    }
}

# check the number of VMs given
if ($Success) {
    $IsMoreThanOne = ([array]($VM.Name | select -Unique)).Count -ge 2
    if (-not $IsMoreThanOne) {
        Write-Warning 'Please provide more than one VM to test parallel functionality'
        $Success = $false
    }
}

# check that all VMs are on the same Azure Subscription ID
if ($Success) {
    $SubID = $VM | foreach {
        [regex]::Match($_.Id,'^\/subscriptions\/([0-9|a-f|-]{36})\/').Groups[1].Value
    }    
    $HasOneSub = ($SubID | select -Unique).Count -eq 1
    if (-not $HasOneSub) {
        Write-Warning 'All provided VMs must be part of the same Azure Subscription'
        $Success = $false
    }
}

# check the Azure command exists
if ($Success) {
    $HasCommand = (Get-Command -Name 'Get-AzContext' -ErrorAction Ignore) -as [bool]
    if (-not $HasCommand) {
        Write-Warning 'Could not find the Get-AzContext command, make sure you have the Az.Accounts module'
        $Success = $false
    }
}

# check that we're in the correct Azure subscription
if ($Success) {
    $AzContext  = Get-AzContext -RefreshContextFromTokenCache -ListAvailable:$false -Verbose:$false 3>$null
    $CurrentSub = $AzContext.Subscription.Id
    $SubID      = $SubID | select -First 1
    if ($CurrentSub -ne $SubID) {
        Write-Warning "Please change to the Azure Subscription with ID: $SubID"
        $Success = $false
    }
}

if (-not $Success) {Write-Warning 'Please check the above pre-requisites'}

Write-Output $Success
}