

## Overview

This is a wrapper around `Invoke-AzVMRunCommand` that adds support for a few things which improves its usefulness significantly.  
Specifically it supports objects (for both input and output), streams (like verbose and warning), timeouts and parallelism.  
It also compresses the output to support sizes a bit larger than 4KB, it shows the remote error records onto the local machine and finally enriches the objects with the computername.

In general I tried to simulate the functionality of `Invoke-Command` through the Azure run command.


## Out-Of-Scope

The following features are out of scope, at least for now:

- no logging in the remote machine (you can do that on your own of course)
- no encryption for input or output (I may add encryption later on)
- you cannot use the `$using:` scope in the scriptblock to pass local variables onto the remote Azure VM (use the `-ParameterList` or `-ArgumentList` options instead)


## Some examples

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

## Timeout settings

- **Execution Timeout**  
Once the script reaches the remote host, then this is the time needed to run that script on that VM (but does not include the time needed to send the results back).  
When the Execution timeout expires then the runspace job that runs on the remote host is stopped and any output up to that point is collected.
- **Delivery Timeout**  
This is the time needed to reach the remote host, to communicate with the Az VM Guest agent service and send the code, and finally to also run the user's script to completion and for the agent to send the results back to your computer. Which means the Delivery Timeout includes the Execution Timeout.  
When the Delivery timeout expires then the `Invoke-AzVMRunCommand` that runs locally is stopped which means you don't get any output.