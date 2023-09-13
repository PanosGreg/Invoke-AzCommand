function Invoke-AzCommand {
<#
.SYNOPSIS
    It runs a remote command in an Azure VM through Invoke-AzVMRunCommand,
    but it adds support for objects, streams and multi-threading.
.EXAMPLE
    $All = Get-AzVM
    Invoke-AzCommand -VM $All -ScriptBlock {$psversiontable}
    # we get an object as output
.EXAMPLE
    $All = Get-AzVM
    Invoke-AzCommand $All {param($Svc) $Svc.Name} -Arg (Get-Service WinRM)
    # we give an object for input
.EXAMPLE
    $All = Get-AzVM
    Invoke-AzCommand $All {Write-Verbose 'vvv' -Verbose;Write-Warning 'www';Write-Output 'aaa'}
    # we get different streams in the output
.EXAMPLE
    $All = Get-AzVM ; $file = 'C:\Temp\MyScript.ps1'
    Invoke-AzCommand $All $file
    # we run a script file instead of a scriptblock on the remote VM
#>
[CmdletBinding(DefaultParameterSetName = 'Scriptblock')]
param (
    [Parameter(Mandatory,Position=0)]
    [ValidateScript({
        $Chk = $_ | foreach {$_.GetType().Name -match 'PSVirtualMachine(List|ListStatus)?$'}
        $Chk -notcontains $false
    })]    
    $VM,  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus]

    [Parameter(Mandatory,Position=1,ParameterSetName = 'Scriptblock')]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory,Position=1,ParameterSetName = 'Scriptfile')]
    [string]$ScriptFile,

    [object[]]$ArgumentList,

    [int]$ThrottleLimit    = 10,    # <-- maximum number of parallel threads used during execution, default is 10
    [int]$DeliveryTimeout  = 666,   # <-- time needed to run the Invoke-AzVMRunCommand, default 10+ minutes (ExecTime plus 1+ minute for AzVMRunCommand to reach the Azure VM)
    [int]$ExecutionTimeout = 600
)

# get the user's script and our functions that we'll use inside the foreach parallel
if ($ScriptFile) {
    try   {$ScriptText  = Get-Content $ScriptFile -Raw -ErrorAction Stop  # <-- this checks if the file is accessible
           $ScriptBlock = [scriptblock]::Create($ScriptText)}             # <-- this checks if it's a PowerShell script
    catch {throw $_}
}
$RemoteScript  = Write-RemoteScript -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Timeout $ExecutionTimeout
$ModuleFolder  = $MyInvocation.MyCommand.Module.ModuleBase
$ScriptsToLoad = 'Invoke-RemoteScript','Initialize-AzModule','Receive-RemoteOutput','Expand-XmlString'
$ScriptList    = $ScriptsToLoad | foreach {Join-Path $ModuleFolder "\Private\$_.ps1"}

# Progress Bar with ForEach Parallel, related variables and setup
$ProgressParams  = [System.Collections.Concurrent.ConcurrentDictionary[int,hashtable]]::new()
$MaxVMNameLength = ($VM.Name | Measure-Object -Property Length -Maximum).Maximum
$ProgressIDNum   = 0
$VMListWithID    = $VM | foreach {
    $ProgressIDNum++
    [void]$ProgressParams.TryAdd($ProgressIDNum,@{})

    $SubID = [regex]::Match($_.Id,'^\/subscriptions\/([0-9|a-f|-]{36})\/').Groups[1].Value
    [pscustomobject] @{
        Name              = $_.Name
        ResourceGroupName = $_.ResourceGroupName
        SubscriptionID    = $SubID   # <-- Azure Subscription ID
        ProgressID        = $ProgressIDNum
    }
}

# run the command with multi-threading and progress bars
$Job = $VMListWithID | ForEach-Object -ThrottleLimit $ThrottleLimit -Verbose -AsJob -Parallel {
    # Progress Bar related variables
      $HashCopy = $using:ProgressParams
      $progress = $HashCopy.$($_.ProgressID)
      $Padding           = $using:MaxVMNameLength - $_.Name.Length
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

    # run the user's script on the remote VM and show the output
    $progress.Status = 'Running remote command...'
    Invoke-RemoteScript -VMName $srv -RGName $rg -ScriptString $scr -Timeout $dur

    # mark progress as completed
    $progress.Completed = $true
}

while ($Job.State -eq 'Running') {
    $ProgressParams.Keys | foreach {
        if (([array]$ProgressParams.$_.Keys).Count -ge 1) {
            $params = $ProgressParams.$_
            Write-Progress @params
        }
    }
    # Wait to refresh to not overload gui
    Start-Sleep -Milliseconds 100
}

# show the results
$out = $Job | Receive-Job -Verbose -AutoRemoveJob -Wait
$out | foreach {Receive-RemoteOutput -InputString $_.Output -FromVM $_.VMName}

}