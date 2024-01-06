
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
# it stops the command due to the timeout expiration
# BUT it does return any partial output (up until the timeout limit)

$results  = Invoke-AzCommand $VM {Get-Service WinRM,'Unknown-Service'}
$results  | select AzComputerName,AzUserName
$error[0] | select AzComputerName,AzUserName
# the returned output is enriched with the VM's name and the Azure account that ran it

Invoke-AzCommand $VM {$env:ComputerName} -AsJob
$job = Get-Job -Name AzCmd*
$job.TargetVM
# run the remote command as a background job. Also the job object has an extra property called TargetVM

$creds = Get-Credential
$block = {
    $srv = 'Server2'
    $usr = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $cim = Get-CimInstance -ComputerName $srv -ClassName win32_operatingsystem
    $dir = Get-ChildItem "\\$srv\c$"
    $icm = Invoke-Command -ComputerName $srv -ScriptBlock {$env:COMPUTERNAME}
    [pscustomobject] @{
        Remote = $srv
        Whoami = $usr
        CIM    = $cim.pscomputername -eq $srv
        DIR    = $dir.Count -gt 1
        ICM    = $icm -eq $srv
    }
}
Invoke-AzCommand $VM $block -Credential $creds
# run the remote command as a different user that has network access to a server in the domain
# by default the SSM Agent runs under the SYSTEM account which does not have any network access.

$StorAccnt = Get-AzStorageAccount   -Name '<azure_storage_account>' -ResourceGroupName '<res_group_name>'
$StorContr = Get-AzStorageContainer -Name '<azure_storage_container>' -Context $StorAccnt.Context
Import-Module Storage
Invoke-AzCommand $VM {Get-Volume} -StorageContainer $StorContr
# use an Azure Storage Container as an intermediate to temporarily save the output results
# to bypass the max length limitation from the native Az VM Guest Agent service (which is just 4KB)
# I'm also loading the Storage module locally in order to have the appropriate formatter for the Volume object from the remote command

$AccntEU  = Get-AzStorageAccount -AccountName '<account_in_EU_location>' -ResourceGroupName '<res_group_in_EU_location>'
$AccntUS  = Get-AzStorageAccount -AccountName '<account_in_US_location>' -ResourceGroupName '<res_group_in_US_location>'
$ContrEU  = Get-AzStorageContainer -Name '<storage_container_name_in_EU>' -Context $AccntEU.Context
$ContrUS  = Get-AzStorageContainer -Name '<storage_container_name_in_US>' -Context $AccntUS.Context
$VM | foreach {
    if     ($_.Location -eq 'eastus2')    {$StorageContainer = $ContrUS}
    elseif ($_.Location -eq 'westeurope') {$StorageContainer = $ContrEU}
    $_ | Add-Member -NotePropertyMembers @{StorageContainer=$StorageContainer} -Force
}
Import-Module Storage
Invoke-AzCommand $VM {Get-Volume} -UseContainerPerVM
# again use Storage Containers with the output, though now we are using the "UseContainerPerVM" switch.
# But this time, we set a specific storage container on each VM based on its location
# so that when the remote command runs, it will send the output to that container in order to minimize cost.
# Because if we were to send everything to one single container, then any traffic that's sent outside of an Azure region
# gets charged, whereas now we keep all traffic within the same locations/regions.
# The property we add to each VM has a specific name ("StorageContainer") and must have a specific type ([AzureStorageContainer])
```