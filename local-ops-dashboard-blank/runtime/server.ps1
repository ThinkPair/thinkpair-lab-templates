param(
  [int]$Port = 4173
)

$ErrorActionPreference = "Stop"
$packageRoot = Split-Path -Parent $PSScriptRoot
$appRoot = [System.IO.Path]::GetFullPath((Join-Path $packageRoot "app"))
$hostAddress = [System.Net.IPAddress]::Parse("127.0.0.1")
$listener = New-Object System.Net.Sockets.TcpListener($hostAddress, $Port)

$mimeTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".js" = "text/javascript; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".png" = "image/png"
  ".jpg" = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".svg" = "image/svg+xml"
  ".ico" = "image/x-icon"
  ".woff2" = "font/woff2"
}

function Write-HttpResponse {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [string]$ContentType,
    [byte[]]$Body,
    [string]$CacheControl = "public, max-age=3600"
  )

  $header = "HTTP/1.1 $StatusCode $StatusText`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nCache-Control: $CacheControl`r`nConnection: close`r`n`r`n"
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
  $Stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($Body.Length -gt 0) {
    $Stream.Write($Body, 0, $Body.Length)
  }
  $Stream.Flush()
}

$listener.Start()
Write-Host "http://127.0.0.1:$Port/"

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($requestLine)) {
        $client.Close()
        continue
      }

      do {
        $line = $reader.ReadLine()
      } while ($null -ne $line -and $line -ne "")

      $parts = $requestLine.Split(" ")
      if ($parts.Length -lt 2 -or $parts[0] -ne "GET") {
        $body = [System.Text.Encoding]::UTF8.GetBytes("Method not allowed")
        Write-HttpResponse -Stream $stream -StatusCode 405 -StatusText "Method Not Allowed" -ContentType "text/plain; charset=utf-8" -Body $body -CacheControl "no-store"
        continue
      }

      $requestPath = [System.Uri]::UnescapeDataString($parts[1].Split("?")[0])
      if ($requestPath -eq "/__dashboard_health") {
        $body = [System.Text.Encoding]::UTF8.GetBytes('{"app":"noise-lab-local-dashboard","ok":true}')
        Write-HttpResponse -Stream $stream -StatusCode 200 -StatusText "OK" -ContentType "application/json; charset=utf-8" -Body $body -CacheControl "no-store"
        continue
      }

      if ($requestPath -eq "/") {
        $relativePath = "index.html"
      } else {
        $relativePath = $requestPath.TrimStart("/").Replace("/", [System.IO.Path]::DirectorySeparatorChar)
      }

      $filePath = [System.IO.Path]::GetFullPath((Join-Path $appRoot $relativePath))
      $safePrefix = $appRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
      if (-not $filePath.StartsWith($safePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        $filePath = Join-Path $appRoot "index.html"
      }

      $body = [System.IO.File]::ReadAllBytes($filePath)
      $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
      $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { "application/octet-stream" }
      $cacheControl = if ($filePath.EndsWith("data\current-data.js", [System.StringComparison]::OrdinalIgnoreCase)) { "no-store, max-age=0" } else { "public, max-age=3600" }
      Write-HttpResponse -Stream $stream -StatusCode 200 -StatusText "OK" -ContentType $contentType -Body $body -CacheControl $cacheControl
    } catch {
      try {
        if ($null -ne $stream) {
          $body = [System.Text.Encoding]::UTF8.GetBytes("Local dashboard server error")
          Write-HttpResponse -Stream $stream -StatusCode 500 -StatusText "Internal Server Error" -ContentType "text/plain; charset=utf-8" -Body $body -CacheControl "no-store"
        }
      } catch {}
    } finally {
      if ($null -ne $client) { $client.Close() }
    }
  }
} finally {
  $listener.Stop()
}

