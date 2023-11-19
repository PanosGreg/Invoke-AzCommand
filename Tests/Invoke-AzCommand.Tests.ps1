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
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    $VM  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus]
)
BeforeDiscovery {
    . (Join-Path $PSScriptRoot 'Test-PesterRequirement.ps1')
    $AllGood = Test-PesterRequirement -UserInput $VM
    if (-not $AllGood) {$SkipAll = $true}
    else               {$SkipAll = $false}
}
BeforeAll {
    # load the module to be tested (that's the SUT, system-under-test)
    Import-Module $PSScriptRoot\..\Invoke-AzCommand.psd1

    # load a helper function that's used to give some additional context
    . (Join-Path $PSScriptRoot 'Write-ExtraInfo.ps1')

    # check if this Pester run used the Detailed or Diag output option
    $ShowDetail = $______parameters.Configuration.Output.Verbosity.Value -match 'Detailed|Diagnostic'
} # BeforeAll

Describe 'Invoke-AzCommand' -Skip:$SkipAll {

    BeforeAll {
        # initial remote command that I'll check a number of things against that
        # this saves us time, so we don't have to run the remote command multiple times
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
        #$Result = Invoke-AzCommand $VM $Block -ExecutionTimeout 10
        # Missing tests:
        # - named parameters
        # - scriptfile
        # - truncated output
    }

    AfterEach {
        # a simple check to show (or not) any etxra info provided for that test
        if ($ExtraInfo -and $ShowDetail) {Write-ExtraInfo $ExtraInfo}
    }

    Context 'Basic Functionality' -Tag Functionality {
        BeforeAll {
            $SampleVM = $VM | Get-Random # <-- get one random VM from the provided input
        }
        It 'Runs a basic remoting command on a VM' {
            $ExtraInfo = 'run a scriptblock remotely on 1 VM, no args,objects,streams,errors or multi-threading'
            Invoke-AzCommand $SampleVM {$env:COMPUTERNAME} | Should -Be $SampleVM.Name
        }
        It 'Stops the command if the timeout expires' {
            $block  = {'Started';Start-Sleep 30;'Finished'}
            $result = Invoke-AzCommand $SampleVM $block -ExecutionTimeout 10
        }
    }

<#
    Context 'Functionality Tests' {}
        Context 'Timeouts'        {} # execution timeout, delivery timeout
        context 'Incorrect input' {} # give non-vm, give non-ps block or non-ps file
        context 'AsJob'            {} # use the -AsJob switch, check TargetVMs property on the job object

    context 'Input Options' {}
        Context 'User parameters'  {} # positional,named
        context 'Object input'     {} # object (just one It block here)
        context 'Script options'   {} # scriptblock, scriptfile
        context 'RunAs'            {} # use the credential option to access remote SMB, CIM, ICM 

    context 'Output Options' {}
        Context 'Error Handling' {} # remote execution errors, VM error (stopped vm, linux vm)
        Context 'Stream Output'  {} # verbose, warning, information
        Context 'Normal Output'  {} # plain string, object, truncated string
        Context 'Enriched Output'   # azcomputername, azusername, for pscustomobjects, error records, PSCO with typename, any other type

    More goals:
    - to check if the command will work with new Az module versions
    - to check if the command will work with new PowerShell versions
    - to check if the command works when ran from Linux or Windows
#>





}