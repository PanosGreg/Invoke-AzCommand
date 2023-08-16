function Expand-XmlString {
[OutputType([String])]
[cmdletbinding()]
param (
    [Parameter(Mandatory,ValueFromPipeline)]
    [string]$InputString
)
    # decode (from base64) and then decompress (with gzip)
    Write-Verbose "Original/Compressed Size: $('{0:N0}' -f $InputString.Length)"
    $data   = [System.Convert]::FromBase64String($InputString)
    $ms     = [System.IO.MemoryStream]::new()
    $ms.Write($data, 0, $data.Length)
    $ms.Seek(0,0) | Out-Null
    $mode   = [System.IO.Compression.CompressionMode]::Decompress
    $gz     = [System.IO.Compression.GZipStream]::new($ms, $mode)
    $sr     = [System.IO.StreamReader]::new($gz)
    $OutStr = $sr.ReadToEnd()
    $sr.Close()  # StreamReader
    $ms.Close()  # MemoryStream
    $gz.Close()  # GZipStream
    Write-Verbose "Uncompressed Size: $('{0:N0}' -f $OutStr.Length)"

    Write-Output $OutStr
}