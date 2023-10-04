

## Some notes about runspaces

# Note:
  when you add the PSDataCollection arguments to BeginInvoke(),
  then the EndInvoke() does NOT return any results
  instead the output is added to the collection
  So you don't really have to call the .EndInvoke(), it's optional
  BUT you do need to .Dispose() the runspace
# Note2:
  By using the PSDataCollection arguments with BeginInvoke()
  we are able to collect any partial output even when we stop
  the runspace (because for example the timeout run out)
# Note3:
  With `[powershell]::Create()` method, we're just using the default runspace
  As-in we don't create a custom runspace.
  With a custom runspace you can configure the SessionState
  like for example add variables or functions or types in the
  runspace, so they can be used within the scriptblock.

## Some notes about prameter sets

If you are getting an error like `Parameter set cannot be resolved using the specified named parameters`  
Then make the parameters **mandatory** so PowerShell can identify what's needed and what not when running a command.


## Some notes regarding the progress bar with the foreach parallel

```PowerShell
# Progress Bar with ForEach Parallel, related variables and setup
# we'll need a thread-safe hashtable for the progress bar
$ProgressParams = [System.Collections.Concurrent.ConcurrentDictionary[int,hashtable]]::new()

# get the max length of the VM name property, we'll use the VMName as the <Activity> label
$Max = ($VM | Measure-Object -Property 'Name' -Maximum).Maximum.Length

## We need to create a unique ID for each item of the input array
## This will be the Key of the concurrent hashtable
## This ID must be an [int], cause the ID param from Write-Progress is [int]
$i = 0
$ListWithID = $VM | foreach {
    $i++
    # add the progress id to the concurrent dictionary
    [void]$ProgressParams.TryAdd($i,@{})

    # add the progress id to the input data set
    $SubID = [regex]::Match($_.Id,'^\/subscriptions\/([0-9|a-f|-]{36})\/').Groups[1].Value
    [pscustomobject] @{
        Name              = $_.Name
        ResourceGroupName = $_.ResourceGroupName
        SubscriptionID    = $SubID   # <-- Azure Subscription ID
        ProgressID        = $i
    }
}

# run the command with multi-threading and progress bars
$Job = $ListWithID | ForEach-Object -ThrottleLimit $ThrottleLimit -Verbose -AsJob -Parallel {
    $HashCopy = $using:ProgressParams
    $progress = $HashCopy.$($_.ProgressID)

    $Padding           = $using:Max - $_.Name.Length
    $progress.Id       = $_.ProgressID
    $progress.Activity = "[{0}{1}]" -f $_.Name,(' '*$Padding)

    $srv = $_.Name
    $rg  = $_.ResourceGroupName
    $sub = $_.SubscriptionID
    $scr = $using:RemoteScript
    $dur = $using:DeliveryTimeout

    $VerbosePreference = $using:VerbosePreference
    $using:ScriptList | foreach {. $_}  # <-- dot-source our helper functions

    # load the Azure modules and set the Subscription
    $progress.Status = 'Loading Azure modules...'
    Initialize-AzModule -SubscriptionID $sub -Verbose:$false

    # run the user's script on the remote VM
    $progress.Status = 'Running remote command...'
    Invoke-RemoteScript -VMName $srv -RGName $rg -ScriptString $scr -Timeout $dur

    # Mark progress as completed
    $progress.Completed = $true
}
```