<#
.SYNOPSIS
    Various functionality tests of Invoke-AzCommand, to ensure that the basic use-cases are working.
.DESCRIPTION
    For these tests to work, there's some requirements that need to be met first.
    - Need to have the Az.Axccounts and Az.Compute modules already installed
    - Need to be logged in to Azure
    - Need to have collected a list of VMs with "Get-AzVM -Status" beforehand
      This list will be passed as input to the tests.
    - Need to have at least 2 Windows VMs running in Azure to test against them.
      Your account needs to have permissions to run commands on those VMs.
    - The VMs need to have the Azure VM Guest Agent running so that the Invoke-AzVMRunCommand
      can work on them.
.EXAMPLE
    $AllVM = Get-AzVM
    $Container = New-PesterContainer -Path .\Invoke-AzCommand.Tests.ps1 -Data @{VM=$AllVM}
    Invoke-Pester -Container $Container -Output Detailed
#>
param (
    $VM  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus]
)
BeforeDiscovery {
    $AllGood = Test-PesterRequirement -UserInput $VM
    if (-not $AllGood) {$SkipAll = $true}
    else               {$SkipAll = $false}
}
BeforeAll {
    # load the module
    Import-Module $PSScriptRoot\..\Invoke-AzCommand.psd1
} # BeforeAll

Describe 'Invoke-AzCommand' -Skip:$SkipAll {

    BeforeAll {
        $Block = {
            param ($Message,$Service)        # <-- positional parameter with object input
            Write-Verbose 'vvv' -Verbose     # <-- Verbose stream
            Write-Warning 'www'              # <-- Warning stream
            Write-Output  'ooo'              # <-- Normal stream with plain string output
            Write-Output $Message            # <-- plain string input
            Get-Service $Service.Name        # <-- Object output
            Get-Service 'Unknown-Service'    # <-- error output
            Start-Sleep 20                   # <-- wait time to test execution timeout
            Write-Output 'Will not be shown' # <-- this will be cut out due to timeout expiration
        }
        $Result = Invoke-AzCommand $VM $Block -ExecutionTimeout 10
        # Missing tests:
        # - named parameters
        # - scriptfile
        # - truncated output
    }
<#
    Context 'Functionality Tests' {}
        Context 'Timeouts'        {} # execution timeout, delivery timeout
        context 'Incorrect input' {} # give non-vm, give non-ps block or non-ps file

    context 'Input Options' {}
        Context 'User parameters'  {} # positional,named
        context 'Object input'     {} # object (just one It block here)
        context 'Script options'   {} # scriptblock, scriptfile

    context 'Output Options' {}
        Context 'Error Handling' {} # remote execution errors, VM error (stopped vm, linux vm)
        Context 'Stream Output'  {} # verbose, warning, information
        Context 'Normal Output'  {} # plain string, object, truncated string
        Context 'Enriched Output'   # azcomputername, azusername, also for error records
#>





}