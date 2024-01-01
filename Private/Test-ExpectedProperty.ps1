function Test-ExpectedProperty {
<#
.SYNOPSIS
    It checks if the input object has the aformentioned property
    Furthermore, it can also check if that property is of the expected type
.NOTES
    This function could also be made with Pester. Meaning I could've written it as 
    a custom assertion function. But then that would mean Pester v5 would be required
    for the module which just adds more dependencies and also increases the loading time
    of the module since it would need to load Pester as well.
#>
[OutputType([bool])]
[CmdletBinding()]
param (
    [Parameter(Mandatory,Position=0)]
    $InputObject,

    [Parameter(Mandatory,Position=1)]
    [string]$PropertyName,

    [Parameter(Position=2)]
    [string]$PropertyType,

    [switch]$ShowMissingPropertyItems,
    [switch]$ShowMissingTypeItems
)

$MissingPropertyList = [System.Collections.Generic.List[object]]::new()
$InputObject | foreach {
    $HasProperty = ($_ | Get-Member -MemberType Properties).Name -contains $PropertyName
    if (-not $HasProperty) {
        $MissingPropertyList.Add($_)
    }
}

$MissingPropertyCount = $MissingPropertyList.Count
if ($MissingPropertyCount -ge 1) {
    Write-Verbose "Found $MissingPropertyCount items that do not have the $PropertyName property"
    if ($ShowMissingPropertyItems) {Write-Output $MissingPropertyList}
}
$HasExpectedProperty = $MissingPropertyCount -eq 0

if ($PropertyType) {
    $Type = $PropertyType -as [type]
    if (-not [bool]$type) {Write-Verbose "Cannot identify the type name $PropertyType"}
    else {
        $MissingTypeList = [System.Collections.Generic.List[object]]::new()
        $InputObject | foreach {
            $IsOfType = $_.$PropertyName -is $Type
            if (-not $IsOfType) {
                $MissingTypeList.Add($_)
            }
        }
        $MissingTypeCount = $MissingTypeList.Count
        if ($MissingTypeCount -ge 1) {
            Write-Verbose "Found $MissingTypeCount items that do not have the $PropertyType type in the $PropertyName property"
            if ($ShowMissingTypeItems) {Write-Output $MissingTypeList}
        }
        $HasExpectedType = $MissingTypeCount -eq 0
    }
}

# show the output
if ($PropertyType) {$HasExpectedProperty -and $HasExpectedType}
else               {$HasExpectedProperty}

}