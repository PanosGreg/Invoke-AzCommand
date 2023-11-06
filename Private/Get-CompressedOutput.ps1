function Get-CompressedOutput {
[cmdletbinding()]
param (
    $InputObject,
    [int]$LimitBytes = 4095  # <-- 4KB is the output limit from Azure's Run Command
)

$CompressionCount = 0

# serialize and compress the output
$xml = [Management.Automation.PSSerializer]::Serialize($InputObject)
$out = Compress-XmlString $xml
$CompressionCount++

# fallback to plain text instead of serialized objects if too big
$Text = [System.Text.StringBuilder]::new()
if ($out.Length -gt $LimitBytes) {
    $Escape  = [char]27
    $Orange  = "$Escape[38;2;255;126;0m"
    $Yellow  = "$Escape[38;2;248;248;0m"
    $Italic  = "$Escape[3m"
    $NoItals = "$Escape[23m"
    $Default = "$Escape[0m"
    [void]$Text.AppendLine("$Orange***Output was$Yellow too long$Orange, so it's shown as plain text $Italic$Yellow(and perhaps truncated)$NoItals$Orange***$Default")
    [void]$Text.Append(($InputObject | Out-String -Width 120))
    $out = Compress-XmlString $Text.ToString()
    $CompressionCount++
}

# fallback to only a part of the plain text if still too big
$limit  = 34000   # <-- so based on the fact that 32K of text (34K-2K on 1st iteration) could compress to approx. ~4KB
$TxtLen = $Text.Length
while ($out.Length -gt $LimitBytes) {
    $limit = $limit - 2000
    if ($TxtLen -gt $limit) {  # <-- need to check to be within the string length for ToString() to work
        $out = Compress-XmlString $Text.ToString(0,$limit)
        $TxtLen = $limit
        $CompressionCount++
    }

    if ($limit -le 2000) {break}  # <-- emergency exit if stuck in the loop for whatever reason
}
[void]$Text.Clear()

# finally give a warning if even that is still too big
if ($out.Length -gt $LimitBytes) {
    $obj = Write-Warning "Output is too long (Length: $($out.Length) bytes)" 3>&1
    $xml = [Management.Automation.PSSerializer]::Serialize($obj)
    $out = Compress-XmlString $xml
    $CompressionCount++
}

Write-Output $out
Write-Verbose "The input was compressed $CompressionCount times"
}