Function Invoke-WithImpersonation {
<#
.SYNOPSIS
    Invoke a scriptblock as another user.
.DESCRIPTION
    Invoke a scriptblock and run it in the context of another user as supplied by -Credential.
.PARAMETER ScriptBlock
    The PowerShell code to run. It is recommended to use '{}.GetNewClosure()' to ensure the scriptblock has access to
    the same values where it was defined. Anything output by this scriptblock will also be outputted by
    Invoke-WithImpersonation.
.PARAMETER Credential
    The PSCredential that specifies the user to run the scriptblock as. This needs to be a valid local or domain user
    except when using '-LogonType NewCredential'. The user specified must have been granted the 'logon as ...' right
    for the -LogonType that was requested (except for -LogonType NewCredential).
.PARAMETER LogonType
    The logon type to use for the impersonated token. By default it is set to 'Interactive' which is the logon type
    used when a user has logged on interactively. Each logon type has their own unique characteristics as specified.
        Batch: Replicates running as a scheduled task, will typically have the full rights of the user specified.
        Interactive: Replicates running as a normal logged on user, may have limited rights depending on whether UAC
            is enabled.
        Network: Replicates running from a network logon like WinRM, will not be able to delegate it's credential to
            further downstream servers.
        NetworkCleartext: Like Network but will have access to its credentials for delegation, similar to using
            CredSSP auth for WinRM.
        NewCredential: Can be used to specify any credentials and any network auth attempts will use those credentials.
            Any local actions are run as the existing users token.
        Service: Replicates running as a Windows service.
.EXAMPLE
    #Run as an interactive logon
    $cred = Get-Credential
    Invoke-WithImpersonation -Credential $cred -ScriptBlock {
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }.GetNewClosure()
.EXAMPLE
    #Access a network path with explicit credentials
    $cred = Get-Credential  # Can be any username/password, does not have to be a valid local or domain account.
    $files = Invoke-WithImpersonation -Credential $cred -LogonType NewCredential -ScriptBlock {
        Get-ChildItem -Path \\192.168.1.1\share\folder
    }.GetNewClosure()
.NOTES
    Starting a new process in the scriptblock will run as the original user and not the user supplied by -Credential.
    Use 'Start-Process' with -Credential to create a new process as another user.

    I need to thank Jordan Borean for his great work on this function.
    The actual source for this is here: https://gist.github.com/jborean93/3c148df03545023c671ddefb2d2b5ffc
    His C# mastery is quite remarkable.
#>
[CmdletBinding(DefaultParameterSetName='Block')]
param (
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='Block')]
    [ScriptBlock]$ScriptBlock,

    [Parameter(Mandatory=$true,Position=0,ParameterSetName='String')]
    [String]$ScriptString,

    [Parameter(Mandatory=$true,Position=1)]
    [PSCredential]$Credential,

    [Parameter(Position=2)]
    [object[]]$ArgumentList,

    [hashtable]$ParameterList,

    [ValidateSet('Batch', 'Interactive', 'Network', 'NetworkCleartext', 'NewCredential', 'Service')]
    [String]$LogonType = 'Interactive'
)

if ($PSCmdlet.ParameterSetName -eq 'String') {
    $ScriptBlock = [scriptblock]::Create($ScriptString)
}

$code = @'
[DllImport("Advapi32.dll", EntryPoint = "ImpersonateLoggedOnUser", SetLastError = true)]
private static extern bool NativeImpersonateLoggedOnUser(
    SafeHandle hToken);
public static void ImpersonateLoggedOnUser(SafeHandle token)
{
    if (!NativeImpersonateLoggedOnUser(token))
    {
        throw new System.ComponentModel.Win32Exception();
    }
}
[DllImport("Advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
private static extern bool LogonUserW(
    string lpszUsername,
    string lpszDomain,
    IntPtr lpszPassword,
    UInt32 dwLogonType,
    UInt32 dwLogonProvider,
    out Microsoft.Win32.SafeHandles.SafeWaitHandle phToken);
public static Microsoft.Win32.SafeHandles.SafeWaitHandle LogonUser(string username, string domain,
    System.Security.SecureString password, uint logonType, uint logonProvider)
{   
    IntPtr passPtr = Marshal.SecureStringToGlobalAllocUnicode(password);
    try
    {
        Microsoft.Win32.SafeHandles.SafeWaitHandle token;
        if (!LogonUserW(username, domain, passPtr, logonType, logonProvider, out token))
        {
            throw new System.ComponentModel.Win32Exception();
        }
        
        return token;
    }
    finally
    {
        Marshal.ZeroFreeGlobalAllocUnicode(passPtr);
    }
}
[DllImport("Advapi32.dll")]
public static extern bool RevertToSelf();
'@
Add-Type -Namespace PInvoke -Name NativeMethods -MemberDefinition $code

$logonTypeInt = switch($LogonType) {
    Interactive      { 2 }  # LOGON32_LOGON_INTERACTIVE
    Network          { 3 }  # LOGON32_LOGON_NETWORK
    Batch            { 4 }  # LOGON32_LOGON_BATCH
    Service          { 5 }  # LOGON32_LOGON_SERVICE
    NetworkCleartext { 8 }  # LOGON32_LOGON_NETWORK_CLEARTEXT
    NewCredential    { 9 }  # LOGON32_LOGON_NEW_CREDENTIALS
}

$user   = $Credential.UserName
$domain = $null
if ($user.Contains('\')) {
    $domain, $user = $user -split '\\', 2
}

try {
    $token = [PInvoke.NativeMethods]::LogonUser(
        $user,
        $domain,
        $Credential.Password,
        $logonTypeInt,
        0  # LOGON32_PROVIDER_DEFAULT
    )
    [PInvoke.NativeMethods]::ImpersonateLoggedOnUser($token)
        
    try {
        if     ($ArgumentList.Count -gt 0)       {$ScriptBlock.Invoke($ArgumentList)}
        elseif ($ParameterList.Keys.Count -gt 0) {& $ScriptBlock @ParameterList}
        else                                     {& $ScriptBlock}
    }
    finally {
        $null = [PInvoke.NativeMethods]::RevertToSelf()
    }
}
catch {
    $PSCmdlet.WriteError($_)
}
finally {
    if ($token) { $token.Dispose() }
}
}