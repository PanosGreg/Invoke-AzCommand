function Get-CompressedOutput {
[cmdletbinding()]
param (
    $InputObject,
    [int]$LimitBytes = 4095  # <-- 4KB is the output limit from Azure's Run Command
)

# serialize and compress the output
$xml = [Management.Automation.PSSerializer]::Serialize($InputObject)
$out = Compress-XmlString $xml

# fallback to plain text instead of serialized objects if too big
if ($out.Length -gt $LimitBytes) {
    $text = $InputObject | Out-String
    $out  = Compress-XmlString $text
}

# fallback to only a part of the plain text if still too big
$limit = 34000   # <-- so based on the fact that 32K of text (34K-2K on 1st iteration) could compress to approx. ~4KB 
while ($out.Length -gt $LimitBytes) {
    $limit = $limit - 2000
    if ($Text.Length -gt $limit) {
        $text = $text.Substring(0,$limit)
        $out = Compress-XmlString $text
    }
    if ($limit -le 2000) {break}  # <-- emergency exit if stuck in the loop for whatever reason
}

# finally give a warning if even that is still too big
if ($out.Length -gt $LimitBytes) {
    $obj = Write-Warning "Output is too long (Length: $($out.Length) bytes)" 3>&1
    $xml = [Management.Automation.PSSerializer]::Serialize($obj)
    $out = Compress-XmlString $xml
}

Write-Output $out
}