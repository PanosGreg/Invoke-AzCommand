
#region Get all the files we need to load

# helper function for use within the .psm1 file
function script:Get-ModuleName {
    $MyInvocation.MyCommand.Module.Name
}

$ModName = Get-ModuleName
$ModFile = $MyInvocation.MyCommand.Path
$ManFile = [System.IO.Path]::ChangeExtension($ModFile,'.psd1')

# get all the file names listed in the manifest
# this also checks that the .psd1 file exists
$FileList = (Import-PowerShellDataFile -Path $ManFile -EA Stop).FileList

# make sure there's at least one file to load
if (([array]$FileList).Count -eq 0) {
    Write-Warning 'Could NOT find any file names in the "FileList" property of the .psd1 manifest'
    Write-Warning 'Please edit the .psd1 manifest to explicitly include all the files of this module in the "FileList" property'
    Write-Warning "The module $ModName was NOT loaded properly"    
    return
}

# now get the module files (this also checks that the files exist)
$ModuleFiles = $FileList | foreach {
    Get-Item -Path (Join-Path $PSScriptRoot $_) -EA Stop
}

# filter all the PowerShell and CSharp files
$PSList = $ModuleFiles | where Extension -eq .ps1
$CSList = $ModuleFiles | where Extension -eq .cs

# now get the public-private functions and all C# classes-enums
$PSFunctions = $PSList | where {$_.Directory.Name -match 'Public|Private'}
$CSharpLibs  = $CSList | where {$_.Directory.Name -eq 'Class'}

#endregion


# Load the Classes & Enumerations
# Note: this needs to be done before loading the functions
Foreach ($File in $CSharpLibs) {
    Try {
        #Add-Type -Path $File.FullName -ErrorAction Stop
    }
    Catch {
        $msg = "Failed to import types from $($File.FullName)"
        Write-Error -Message $msg
        Write-Error $_ -ErrorAction Stop
    }
}

# Load the functions
Foreach($Import in $PSFunctions) {
    Try {
        . $Import.FullName
    }
    Catch {
        $msg = "Failed to import function $($Import.FullName)"
        Write-Error -Message $msg
        Write-Error $_ -ErrorAction Stop
    }
}


# Finally do anything else you might need for the module to work

## NOTE: the exported public command Invoke-AzCommand does NOT need the
#        Azure modules, BUT the foreach parallel threads that it opens
#        need them. So although this module may not need it per se in
#        order to load and run, the background threads require it.


## NOTE #1:
#  The purpose of dot sourcing all the functions with their explicit file names
#  is for security reasons.
#  Otherwise if you just "dir *.ps1" and dot source everything with a foreach loop
#  then anyone who can inject a .ps1 file in your module folder will be executed
#  whenever the module gets imported.
#  I'm using the "FileList" property from the .psd1 file, instead of hardcoding the
#  file names here, so the module manifest is the source of truth.

## NOTE #2:
#  Unfortunately the $MyInvocation.MyCommand.Module.FileList does not work here (inside the .psm1)
#  even when I get it through a function, so I worked around that with Import-PowerShellDataFile
