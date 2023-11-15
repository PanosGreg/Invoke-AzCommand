function Test-AzureSubscription {
<#
.NOTES
    I have to check for the Az Sub and make sure it's the same on all VMs
    because if the user wants to run his command as another user, by suplying Credentials
    then there is one problem.
    The way I encrypt the creds is by using the Azure Subscription ID and I do that outside
    of the foreach parallel. As-in we compile the remote script once and then use it on all
    parallel jobs. But if each VM may be on a different Az Sub, then I need to provide that
    each time cause then the encryption will return different strings. So I opted to keep it
    simple and if the user wants to run the Invoke-AzCommand on different subs, then he can
    do so with a loop of his own, as-in run the Invoke-AzCommand multiple times. one for each
    Azure Subscription.
#>
[OutputType([bool])]
[cmdletbinding()]
param ($VMList)
    # get the Azure Subscription we're currently on
    $AzContext  = Get-AzContext -RefreshContextFromTokenCache -ListAvailable:$false -Verbose:$false 3>$null
    $CurrentSub = $AzContext.Subscription.Id

    # check each VM is on that subscription
    $CheckList = $VMList | foreach {
        $Rgx   = '^\/subscriptions\/([0-9|a-f|-]{36})\/'
        $SubID = [regex]::Match($_.Id,$Rgx).Groups[1].Value
        $SubID -eq $CurrentSub
    }
    if ($CheckList -contains $false) {
        Write-Warning "Not all VMs are on the same Azure Subscription."
        $result = $false
    }
    else {$result = $true}

    Write-Output $result   # <-- [bool]
}