function Compress-XmlString {
[OutputType([String])]   # <-- Base64 encoded string
[cmdletbinding()]
param (
    [Parameter(Mandatory,ValueFromPipeline)]
    [string]$InputString
)
    # compress (with gzip) and then encode (with base64) 
    Write-Verbose "Original/Uncompressed Size: $('{0:N0}' -f $InputString.Length)"
    $ms     = [System.IO.MemoryStream]::new()
    $mode   = [System.IO.Compression.CompressionMode]::Compress
    $gz     = [System.IO.Compression.GZipStream]::new($ms, $mode)
    $sw     = [System.IO.StreamWriter]::new($gz)
    $sw.Write($InputString)
    $sw.Close()
    $bytes  = $ms.ToArray()
    $OutStr = [System.Convert]::ToBase64String($bytes) 
    $ms.Close()  # MemoryStream
    $gz.Close()  # GZipStream
    Write-Verbose "Compressed Size: $('{0:N0}' -f $OutStr.Length)"

    Write-Output $OutStr
}