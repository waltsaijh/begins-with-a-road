param([int]$Port = 8765, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$webRoot = [IO.Path]::GetFullPath($PSScriptRoot)
if (-not (Test-Path -LiteralPath (Join-Path $webRoot 'index.html'))) {
    throw 'Place this launcher beside the exported index.html.'
}
$server = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
$server.Start()
$url = "http://127.0.0.1:$Port/index.html"
Write-Host "Begins With a Road: $url"
Write-Host 'Keep this window open while playing. Close it to stop the server.'
if (-not $NoBrowser) {
    $chrome = @("$env:LOCALAPPDATA/Google/Chrome/Application/chrome.exe", "$env:ProgramFiles/Google/Chrome/Application/chrome.exe", "${env:ProgramFiles(x86)}/Google/Chrome/Application/chrome.exe") | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($chrome) { Start-Process -FilePath $chrome -ArgumentList $url }
    else { Write-Host 'Open the URL above in Chrome.' }
}
$mime = @{'.html'='text/html; charset=utf-8'; '.js'='application/javascript'; '.wasm'='application/wasm'; '.pck'='application/octet-stream'; '.png'='image/png'; '.svg'='image/svg+xml'; '.json'='application/json'; '.ico'='image/x-icon'}
try {
    while ($true) {
        $client = $server.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
            $request = $reader.ReadLine()
            if (-not $request) { continue }
            while ($reader.ReadLine()) { }
            $parts = $request.Split(' ')
            if ($parts.Length -lt 2) { continue }
            $relative = [Uri]::UnescapeDataString(([Uri]("http://localhost"+$parts[1])).AbsolutePath).TrimStart('/')
            if (-not $relative) { $relative = 'index.html' }
            $target = [IO.Path]::GetFullPath((Join-Path $webRoot $relative))
            $allowed = $target.StartsWith($webRoot+[IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
            $status = '200 OK'
            $contentType = $mime[[IO.Path]::GetExtension($target)]
            if (-not $contentType) { $contentType = 'application/octet-stream' }
            if ($parts[0] -notin @('GET','HEAD')) {
                $status = '405 Method Not Allowed'; $body = [Text.Encoding]::UTF8.GetBytes('Method not allowed')
            } elseif (-not $allowed -or -not [IO.File]::Exists($target)) {
                $status = '404 Not Found'; $body = [Text.Encoding]::UTF8.GetBytes('Not found')
            } else { $body = [IO.File]::ReadAllBytes($target) }
            $headers = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCross-Origin-Opener-Policy: same-origin`r`nCross-Origin-Embedder-Policy: require-corp`r`nCross-Origin-Resource-Policy: same-origin`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
            $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
            $stream.Write($headerBytes,0,$headerBytes.Length)
            if ($parts[0] -ne 'HEAD') { $stream.Write($body,0,$body.Length) }
            $stream.Flush()
        } catch { Write-Warning $_.Exception.Message }
        finally { $client.Dispose() }
    }
} finally { $server.Stop() }
