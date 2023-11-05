

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

## Some notes about parameter sets

If you are getting an error like `Parameter set cannot be resolved using the specified named parameters`  
Then make the parameters **mandatory** so PowerShell can identify what's needed and what not when running a command.

## Some examples below

I'm just going to copy/paste the examples I have in the public function, you can always have a look with `Get-Help Invoke-AzCommand -Examples`

```PowerShell
Invoke-AzCommand -VM (Get-AzVM) -ScriptBlock {$PSVersionTable}
# we get an object as output

Invoke-AzCommand (Get-AzVM) {param($Svc) $Svc.Name} -Arg (Get-Service WinRM)
# we give an object for input

$All = Get-AzVM
Invoke-AzCommand $All {Write-Verbose 'vvv' -Verbose;Write-Warning 'www';Write-Output 'aaa'}
# we get different streams in the output

$All = Get-AzVM ; $file = 'C:\Temp\MyScript.ps1'
Invoke-AzCommand $All $file
# we run a script file instead of a scriptblock

$All = Get-AzVM
Invoke-AzCommand $All {param($Size,$Name) "$Name - $Size"} -Param @{Name='John';Size='XL'}
# we pass named parameters instead of positional

# get a running Azure Linux VM (not Windows) or a Windows VM that is stopped (not running)
Invoke-AzCommand $LinuxVM {$env:ComputerName}
Invoke-AzCommand $StoppedVM {$env:ComputerName}
# it returns human readable error messages with all the relevant details

Invoke-AzCommand $VM {Get-Service Non-Existing-Service}
# it returns the actual error message from the remote VM as-if it was local

Invoke-AzCommand $VM {Get-Service -EA 0}
# when the output exceeds the limit of the AzVM Run Command (as-in more than 4kb)
# then it falls back to plain text (not objects) and truncates the output as needed

Invoke-AzCommand $VM {'Started';Start-Sleep 30;'Finished'} -ExecutionTimeout 10
# it returns partial output, due to the timeout expiration

$results  = Invoke-AzCommand $VM {Get-Service WinRM,'Unknown-Service'}
$results  | select AzComputerName,AzUserName
$error[0] | select AzComputerName,AzUserName
# the returned output is enriched with the VM's name and the Azure account that ran it
```