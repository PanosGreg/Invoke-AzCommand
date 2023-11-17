

## Overview

This PowerShell module exposes a single command, the **`Invoke-AzCommand`**,  that you can use to run PowerShell code on Windows VMs in Azure.

You'll need to have the Azure modules (_Az.Compute_ and _Az.Accounts_) and login to Azure through PowerShell for this module to work.

This is a wrapper around the native `Invoke-AzVMRunCommand` that adds support for a few things which improves its usefulness significantly.  
Specifically it supports:
- **Objects**  
(for both input and output, so you're not getting plain strings in the output and you can also pass objects not just strings for input)
- **PowerShell Streams**  
(like Verbose and Warning streams in your local output)
- **Timeouts**  
(so you don't have to wait 10 minutes or 1 hour to get an error if the command breaks)
- **Multi-Threading**  
(for parallel execution since Azure is quite slow and each command takes about ~60 seconds)
- **Impersonation**  
(to _RunAs_ a different user so you can access the network since the agent runs with System by default).

It also compresses the output to support sizes a bit larger than 4KB (since that's the current limit from the Azure service), it shows the remote error records onto the local machine and finally enriches the objects with the computername.

In general I tried to simulate the functionality of `Invoke-Command` through the Azure run command.

## Installation

```PowerShell
# clone the repo locally with git
git clone https://github.com/PanosGreg/Invoke-AzCommand.git

# or get the repo with the github tool
gh repo clone PanosGreg/Invoke-AzCommand

# or if you don't have any of the above, just download the zip and extract it locally
$url = 'https://github.com/PanosGreg/Invoke-AzCommand/archive/refs/heads/master.zip'
$zip = 'C:\Temp\Invoke-AzCommand.zip'                 # <-- this is just an example path, place it wherever you want
[System.Net.WebClient]::new().DownloadFile($url,$file)
Expand-Archive -Path $zip -DestinationPath C:\Temp    # <-- again this path is just an example
```
**This module requires PowerShell v7+ to work.**  
So if you don't have it, you'll need to _[install it.](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)_

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
```
Please see the [**examples.md**](./examples.md) file for more use-cases and examples.

## Timeout settings

The `Invoke-AzCommand` has two different parameters regarding timeouts. This is a quick clarification on what each one does.
- **Execution Timeout**  
Once the script reaches the remote host, then this is the time needed to run that script on that VM (but does not include the time needed to send the results back).  
When the Execution timeout expires then the runspace job that runs on the remote host is stopped and any output up to that point is collected.
- **Delivery Timeout**  
This is the time needed to reach the remote host, to communicate with the Az VM Guest agent service and send the code, and finally to also run the user's script to completion and for the agent to send the results back to your computer. Which means the Delivery Timeout includes the Execution Timeout.  
When the Delivery timeout expires then the `Invoke-AzVMRunCommand` that runs locally is stopped which means you don't get any output.


## Official documentation from MS

The Microsoft page for running scripts on Windows VMs through `Invoke-AzVMRunCommand` for reference. Where you can see the limitations of "Run Command".  
[Run scripts in your Windows VM by using action Run Commands](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/run-command)

## Out-Of-Scope

The following features are out of scope, at least for now:

- no logging in the remote machine (you can do that on your own of course)
- no encryption on the input or output (I may add proper encryption later on).  
  Although I do encrypt any credentials provided through the `-Credential` parameter.
- you cannot use the `$using:` scope in the scriptblock to pass local variables onto the remote Azure VM (but you can use the `-ParameterList` or `-ArgumentList` options for that instead)


