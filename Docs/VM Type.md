
## Type Differences

The `Get-AzVM` command returns **4 different types** depending on the way you use it.
These are:
- _Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine_
- _Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineInstanceView_
- _Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineList_
- _Microsoft.Azure.Commands.Compute.Models.PSVirtualMachineListStatus_

```PowerShell
# assume you have 2 VMs, web1 and web2, on a resource group called "prod"
$SingleNoStatus   = Get-AzVM -Name web1 -ResourceGroupName prod          # -->  PSVirtualMachine
$SingleWithStatus = Get-AzVM -Name web1 -ResourceGroupName prod -Status  # -->  PSVirtualMachineInstanceView
$MultiNoStatus    = Get-AzVM -Name web* -ResourceGroupName prod          # -->  PSVirtualMachineList
$MultiWithStatus  = Get-AzVM -Name web* -ResourceGroupName prod -Status  # -->  PSVirtualMachineListStatus


$SingleNoStatus.GetType().Name      # -->  PSVirtualMachine
$SingleWithStatus.GetType().Name    # -->  PSVirtualMachineInstanceView
$MultiNoStatus[0].GetType().Name    # -->  PSVirtualMachineList
$MultiWithStatus[0].GetType().Name  # -->  PSVirtualMachineListStatus

# All of them have .Name & .ResourceGroupName
# But PSVirtualMachineInstanceView does not have .Location and .NetworkProfile
```