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
    $Creds = Get-Credential
    $Container = New-PesterContainer -Path .\Invoke-AzCommand.Tests.ps1 -Data @{VM=$AllVM;Credential=$Creds}
    Invoke-Pester -Container $Container -Output Detailed
.EXAMPLE
    $AllVM = Get-AzVM
    $Creds = Get-Credential
    $Container = New-PesterContainer -Path .\Invoke-AzCommand.Tests.ps1 -Data @{VM=$AllVM;Credential=$Creds}
    Invoke-Pester -Container $Container -Output Detailed -Tag Input
    # run only a small subset of the total tests that have a specific tag
#>
param (
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    $VM,  # <-- must be [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine] or [...PSVirtualMachineList] or [...PSVirtualMachineListStatus]

    [Parameter(Mandatory)]
    $Credential
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
            $result = Invoke-AzCommand $SampleVM {'BasicTest'}
            $result | Should -Be 'BasicTest'
        }
        It 'Errors out if given an invalid VM' {
            {Invoke-AzCommand InvalidVM {}} | Should -Throw '*Please provide a valid Azure VM object type'
        }
        It 'Errors out if given a non-existing script file' {
            {Invoke-AzCommand $SampleVM NonExistingScriptFile} | Should -Throw '*Cannot find path*'
        }
        It 'Runs multiple remote commands in parallel' {
            $result = Invoke-AzCommand $VM {'BasicTest'}
            $result | Should -HaveCount $VM.Count
        }
    } #Context Basic

    Context 'Background Job option' -Tag AsJob {
        BeforeAll {
            $SampleVM = $VM | Get-Random # <-- get one random VM from the provided input
            $job      = Invoke-AzCommand $SampleVM {'JobTest'} -AsJob
            $result   = $job | Receive-Job -Wait
        }
        It 'Runs as a background job' {
            $result | Should -Be 'JobTest'
        }
        It 'Prefixes the Job with "AzCmd"' {
            $job.Name | Should -BeLike 'AzCmd*'
        }
    } #Context Job

    Context 'Timeout functionality' -Tag Timeout {
        BeforeAll {
            $SampleVM = $VM | Get-Random # <-- get one random VM from the provided input
            $block    = {'Started';Start-Sleep 30;'Finished'}
            $result   = Invoke-AzCommand $SampleVM $block -ExecutionTimeout 10 *>&1
        }
        It 'Stops the command if the "Execution" timeout expires' {
            $result[0] | Should -BeOfType System.Management.Automation.WarningRecord
            $result[0].Message | Should -BeLike '*Execution timeout has expired*'
        }
        It 'Collects any partial output up to the timeout limit' {
            $result | Should -Contain 'Started'
            $result | Should -Not -Contain 'Finished'
        }
        It 'Stops the command if the "Delivery" timeout expires' {
            $DeliveryTimout = Invoke-AzCommand $SampleVM {$env:COMPUTERNAME} -DeliveryTimeout 2 *>&1
            $DeliveryTimout[0] | Should -BeOfType System.Management.Automation.WarningRecord
            $DeliveryTimout.Message | Should -BeLike '*InvokeAzVMRunCommand timeout exceeded*'
        }
    } #Context Timeout

    Context 'Input options' -Tag Input {
        BeforeAll {
            $SampleVM = $VM | Get-Random # <-- get one random VM from the provided input
        }
        It 'Accepts unnamed, positional parameters' {
            $block  = {param($First,$Second) '{0}-{1}' -f $First,$Second}
            $result = Invoke-AzCommand $SampleVM $block -ArgumentList 'Test1','Test2'
            $result | Should -Be 'Test1-Test2'
        }
        It 'Can pass objects as parameters' {
            $block  = {param($Svc) $Svc.Name}
            $result = Invoke-AzCommand $SampleVM $block -ArgumentList (Get-Service WinRM)
            $result | Should -Be 'WinRM'
        }
        It 'Accepts named parameters' {
            $block  = {param($Last,$First) '{0}.{1}' -f $First,$Last}
            $result = Invoke-AzCommand $SampleVM $block -ParameterList @{First='John';Last='Smith'}
            $result | Should -Be 'John.Smith'
        }
        It 'Can use a script file instead of a scriptblock' {
            $file   = [System.IO.Path]::GetTempFileName()
            $code   = {(Get-Service WinRM).Name}.ToString() | Out-File $file -Force
            $result = Invoke-AzCommand $SampleVM $file
            $result | Should -Be 'WinRM'
            Remove-Item $file -Force
        }
        It 'Can run a scriptblock as a different user on the remote VM' {
            $block  = {[System.Security.Principal.WindowsIdentity]::GetCurrent().Name}
            $result = Invoke-AzCommand $SampleVM $block -Credential $Credential
            $result | Should -Be $Credential.UserName
        }
    } #Context Input

    Context 'Output Options' -Tag Output {
        BeforeAll {
            $SampleVM = $VM | Get-Random # <-- get one random VM from the provided input
        }
        It 'Get remote errors locally' {
            $block = {Get-Service Non-Existing-Service}
            Invoke-AzCommand $SampleVM $block -ErrorAction SilentlyContinue -ErrorVariable err
            $err.Exception.Message | Should -BeLike 'Cannot find any service*'
        }
        It 'Get remote Verbose and Warning streams locally' {
            $block  = {Write-Verbose 'vvv' -Verbose;Write-Warning 'www'}
            $result = Invoke-AzCommand $SampleVM $block *>&1
            $result[0] | Should -BeOfType System.Management.Automation.VerboseRecord
            $result[1] | Should -BeOfType System.Management.Automation.WarningRecord
        }
        It 'Falls back to plain string if serialized output is too big' {
            $block  = {Get-Volume}
            $result = Invoke-AzCommand $SampleVM $block
            $result | Should -BeOfType String
        }
        It 'Adds extra properties to the output' {
            $block  = {[pscustomobject]@{Name='test';Size=100;PSTypeName='ThatsMyType'}}
            $result = Invoke-AzCommand $SampleVM $block
            $result.AzComputerName | Should -Not -BeNullOrEmpty
            $result.AzUserName     | Should -Not -BeNullOrEmpty
        }
    } #Context Output

} #Describe Invoke-AzCommand


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