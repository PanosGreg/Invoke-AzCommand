﻿# Module manifest for module 'Invoke-AzCommand'
# Generated by: Panos Grigoriadis
# Generated on: 30 Jul 2023

@{
RootModule        = 'Invoke-AzCommand.psm1'
ModuleVersion     = '1.3.0'
GUID              = '0b242b1e-b061-49a0-914d-dc9daa4e4615'
Author            = 'Panos Grigoriadis'
#CompanyName       = ''
#Copyright         = ''
Description       = 'Function for running remote commands on Azure Windows VMs.'
PowerShellVersion = '7.0'     # <-- this module uses the "ForEach -Parallel" so it needs PS 7+
#RequiredModules   = @()
FunctionsToExport = 'Invoke-AzCommand'
#CmdletsToExport   = @()
AliasesToExport   = @()       # <-- the empty array makes sure no aliases are exported
FileList          = 'readme.md',
                    'Invoke-AzCommand.psm1',
                    'Invoke-AzCommand.psd1',
                    'Public\Invoke-AzCommand.ps1',
                    'Private\Write-RemoteScript.ps1',
                    'Private\Invoke-RemoteScript.ps1',
                    'Private\Initialize-AzModule.ps1',
                    'Private\Receive-RemoteOutput.ps1',
                    'Private\Compress-XmlString.ps1',
                    'Private\Expand-XmlString.ps1',
                    'Private\ConvertBase64.ps1',
                    'Private\Start-RunspaceJob.ps1',
                    'Private\Get-CompressedOutput.ps1',
                    'Private\Get-ErrorRecord.ps1',
                    'Private\Invoke-ForEachParallel.ps1',
                    'Private\Get-AzVMError.ps1'
PrivateData = @{
    PSData = @{
        Tags         = 'PowerShell', 'Azure', 'Remoting'
        ProjectUri   = 'https://github.com/PanosGreg/Invoke-Command'
        ReleaseNotes = 'Helper function for remoting into Windows Azure VMs.'
    }
}
}

