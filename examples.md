
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
```