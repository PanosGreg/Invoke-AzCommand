
## Techniques used in the module

This module uses a number of different techniques for its implementation.
They can be found mostly in the private functions.

Here's some of them:

- The Abstract Syntax Tree (AST), in `Remove-Comments`
- Thread-safe type usage in `Invoke-ForeachParallel`
- .NET stream classes in `Compress-XmlString`
- ErrorRecord creation in `Get-ErrorRecord`
- .NET reflection in `Get-ErrorRecord`
- Background jobs in `Start-FunctionJob`
- PowerShell runspaces in `Start-RunspaceJob`
- Platform Invocation Services (P/Invoke through C#) in `Invoke-WihtImpersonation`
- PowerShell output streams (and stream handling) in `Receive-RemoteOutput`
- Function aliases (for dynamic input) in `ConvertFrom-BaseString`
- Multiple parameter sets in `Invoke-AzCommand`
- Dyanmic variable (through debugging breakpoint) in `Invoke-ForeachParallel`
- Regular exression in `Test-AzureSubscription`


