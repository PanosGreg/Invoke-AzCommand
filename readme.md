

## Overview

This PowerShell module exposes a single command, the **`Invoke-AzCommand`**,  that you can use to run PowerShell code on Windows VMs in Azure.

You'll need to have the Azure modules (_Az.Compute_ and _Az.Accounts_) and login to Azure through PowerShell for this module to work.

## Idea

The native `Invoke-AzVMRunCommand` from Microsoft is lacking a lot of needed functionality.  
The company that gave us **Invoke-Command** and **PowerShell Remoting** falls behind when it comes to remote execution in Azure, even through PowerShell nonetheless. I realized there's no alternative out there that does what I wanted to do. So I made `Invoke-AzCommand` to fix the gap.

There should be a remote execution method on Azure VMs through PowerShell that's easy-to-use, simple, and supports objects, streams and multi-threading at the very least. Now there is.


## Functionality

This is a wrapper around the native `Invoke-AzVMRunCommand` that adds support for a few key areas which improves its usefulness significantly.  
Specifically it supports:
- **Objects**  
(for both input and output, so you're not getting plain strings in the output and you can also pass objects for input, not just strings)
- **PowerShell Streams**  
(like Verbose, Warning and Error streams from the remote code into your local output)
- **Timeouts**  
(so you don't have to wait 10 minutes or 1 hour to get an error if the command breaks)
- **Multi-Threading**  
(for parallel execution per VM since Azure is quite slow and each command takes about ~60 seconds)
- **Impersonation**  
(to _RunAs_ a different user so you can access network recources since the agent service runs with _System_ by default).
- **Storage Container Option**  
(optionally use Azure Blob Storage as an intermediate store to bypass the limitation of 4KB on the output message)

It also compresses the output to support sizes a bit larger than 4KB (since that's the current limit from the Azure service), it shows the remote error records onto the local machine and finally enriches the objects with extra properties like the Azure computername and username. When the user gives credentials to run-as a different account on the remote VM(s), those credentials are encrypted.

The general idea was to simulate the functionality of `Invoke-Command` as best as I could, through the Azure run command.

## Disclaimer

I know that MS has recently introduced the `Get-AzVMRunCommand` and also the `Set-AzVMRunCommand`, but unfortunately these are missing a lot of features as well. So it wasn't the answer to the problem after all.

## Installation

```PowerShell
# go to a folder where you'll place the repo
cd C:\Temp    # <- this path is just an example 

# clone the repo locally with git
git clone https://github.com/PanosGreg/Invoke-AzCommand.git

# or get the repo with the github tool
gh repo clone PanosGreg/Invoke-AzCommand

# or if you don't have any of the above, just download the zip and extract it locally
$url = 'https://github.com/PanosGreg/Invoke-AzCommand/archive/refs/heads/master.zip'
$zip = 'C:\Temp\Invoke-AzCommand.zip'                 # <-- this is just an example path, place it wherever you want
[System.Net.WebClient]::new().DownloadFile($url,$file)
Expand-Archive -Path $zip -DestinationPath C:\Temp    # <-- again this path is just an example

# finally load the module into your session
Import-Module C:\Temp\Invoke-AzCommand                            # <-- you can import using just the folder name
Import-Module C:\Temp\Invoke-AzCommand\Invoke-AzCommand.psd1      # <-- OR you can import it using the .psd1 file 
```
**This module requires PowerShell v7+ to work.**  
So if you don't have it, you'll need to _[install it.](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)_

## Some examples

I'm just going to copy/paste the examples I have in the public function, you can always have a look with `Get-Help Invoke-AzCommand -Examples`

```PowerShell
# first make sure you're logged in to Azure
Set-AzContext ....  # <-- put your Azure subscription name here
$Flt = {
    $_.StorageProfile.OsDisk.OsType -eq 'Windows' -and  # <-- filter all windows VMs
    $_.PowerState -eq 'VM running'                      # <-- filter all running VMs
}
$VM = Get-AzVM -Status | where $flt   
# obviously you can filter your list even further to only specific VMs if you want

Invoke-AzCommand -VM $VM -ScriptBlock {$PSVersionTable}
# we get an object as output

Invoke-AzCommand $VM {param($Svc) $Svc.Name} -Arg (Get-Service WinRM)
# we give an object for input

Invoke-AzCommand $VM {Write-Verbose 'vvv' -Verbose;Write-Warning 'www';Write-Output 'aaa'}
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

## Storage Container settings
The `Invoke-AzCommand` has an option to use an Azure Storage Container in order to bypass the default limitation of 4KB on the output message. This is done by uploading the output into a Storage Container and then getting it locally to process the results. There are some requirements of course for this functionality to work. The remote server needs to have the Azure modules installed and also needs a Managed Identity that has access to the Storage Container in order to upload the output. Then your local account (or the Azure account that runs the Invoke-AzCommand anyhow) must also have access to that container in order to download the results to your computer.  
Once the results are downloaded from the Storage Container, then they are deleted, so no files are left behind in Azure Storage.  

There is also second way to use this functionality. And this is to specify an individual storage container on each VM. This way if you have VMs in different regions (for ex. in US and in EU locations, on the same Azure subscription) then each of those VMs can send their results to their local Storage Container. This way we avoid any extra costs from sending traffic outside of the Azure region. The results will then be downloaded locally from each of those storage containers, in which case do note that this can incur some costs if you're running the Invoke-AzCommand from a computer that is outside of those Azure regions.

For this 2nd option to work, you'll need to add the storage container to each VM manually, before running `Invoke-AzCommand`. This can be done easily with a `foreach` loop and the `Add-Member` command. Please see [**examples.md**](./examples.md) for the details on that.

## Official documentation from MS

The Microsoft page for running scripts on Windows VMs through `Invoke-AzVMRunCommand` for reference. Where you can see the limitations of "Run Command", like the 4KB output limit and the 4MB input limit.  
[Run scripts in your Windows VM by using action Run Commands](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/run-command)

## Out-Of-Scope

The following features are out of scope, at least for now:

- no logging in the remote machine (you can do that on your own of course)
- no encryption in the input or output (I may add proper encryption later on).  
  Although I do encrypt any credentials provided through the `-Credential` parameter.
- you cannot use the `$using:` scope in the scriptblock to pass local variables onto the remote Azure VM (although you can use the `-ParameterList` or `-ArgumentList` options for that instead)

## TODO

You can have a look at the `"\Docs\New Feature Ideas.txt"` if you want to see what I'm thinking about this module.

