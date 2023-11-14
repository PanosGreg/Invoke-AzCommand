



$Name = 'SHiPS'
$Mod  = Import-Module $Name -PassThru

# compress the module into a zip file
$ProgressPreference = 'SilentlyContinue'
$dest = Join-Path $env:TEMP "$($Mod.Name).zip"
Compress-Archive $Mod.ModuleBase -Destination $dest -Force

# check the size
$Size = (Get-Item $dest).Length
if ($Size -gt 1mb) {return "Zip file size is too big ($Size)"}

# now read the zip and encode it with base64
$txt = Get-Content $dest -Raw

# encode it
$Bytes  = [System.Text.Encoding]::ASCII.GetBytes($txt)
$Base64 = [System.Convert]::ToBase64String($Bytes)

# clean up
Remove-Item $dest -Force

#######

# so now, you need to decode it, then save it into a zip file
# then unzip it somewhere. And then you can import the module