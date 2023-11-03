function Initialize-AzModule {
[OutputType([void])]
[CmdletBinding()]
param (
    #[ValidateSet('csocoupadev','csoprod','coupahost','coupadev')]
    [string]$SubscriptionID,

    [string[]]$Module = @('Az.Accounts','Az.Compute')
)

# need to handle the verbose preference manually
# cause Import-Module doesn't respect it when it loads the Azure modules
$Orig = $Global:VerbosePreference
$Global:VerbosePreference = 'SilentlyContinue'

# load the Azure modules
$LoadedModules = (Get-Module).Name
foreach ($Mod in $Module) {
    if ($LoadedModules -notcontains $Mod) {
        Import-Module $Mod -Verbose:$false
    }
}

# revert back the verbose preference to what it was
$Global:VerbosePreference = $Orig

# set the Azure subscription, this also logs in to Azure
$ctx = Get-AzContext -RefreshContextFromTokenCache -ListAvailable:$false -Verbose:$false 3>$null
$CurrentSub = $ctx.Subscription.Id
if ($CurrentSub -ne $SubscriptionID) {
    Set-AzContext -Subscription $SubscriptionID -Verbose:$false -EA Stop 3>$null | Out-Null
}
# note: I'm silencing the warning stream to avoid the annoying message "Fallback context save mode to process"
}