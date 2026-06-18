param(
  [int]$Port = 5500,
  [string]$HostName = "127.0.0.1"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Node = Get-Command node -ErrorAction SilentlyContinue
$Ssh = Get-Command ssh.exe -ErrorAction SilentlyContinue

if (-not $Node) {
  throw "Node.js was not found on PATH. Install Node.js or start a local server manually."
}

if (-not $Ssh) {
  throw "OpenSSH client was not found on PATH. Install OpenSSH or use another tunnel tool."
}

function Get-ListeningProcessId {
  param([int]$LocalPort)

  $connection = Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($connection) {
    return [int]$connection.OwningProcess
  }

  return $null
}

function Start-StaticServer {
  param(
    [string]$Root,
    [string]$Address,
    [int]$LocalPort
  )

  $serverScript = @"
const http = require("http");
const fs = require("fs");
const path = require("path");
const root = process.cwd();
const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".webp": "image/webp"
};

http.createServer((req, res) => {
  const url = new URL(req.url, "http://$Address");
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === "/") pathname = "/index.html";

  const filePath = path.normalize(path.join(root, pathname));
  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }

    res.writeHead(200, {
      "Content-Type": types[path.extname(filePath).toLowerCase()] || "application/octet-stream"
    });
    res.end(data);
  });
}).listen($LocalPort, "$Address");
"@

  Start-Process `
    -FilePath $Node.Source `
    -ArgumentList @("-e", $serverScript) `
    -WorkingDirectory $Root `
    -WindowStyle Hidden `
    -PassThru
}

$serverPid = Get-ListeningProcessId -LocalPort $Port
$startedServer = $false

if (-not $serverPid) {
  $serverProcess = Start-StaticServer -Root $ProjectRoot -Address $HostName -LocalPort $Port
  Start-Sleep -Seconds 1
  $serverPid = Get-ListeningProcessId -LocalPort $Port
  $startedServer = $true

  if (-not $serverPid) {
    if ($serverProcess -and -not $serverProcess.HasExited) {
      Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
    }

    throw "Failed to start a local static server on http://$HostName`:$Port"
  }
}

$localUrl = "http://$HostName`:$Port"

try {
  $response = Invoke-WebRequest -Uri $localUrl -UseBasicParsing -TimeoutSec 8
  if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
    throw "Unexpected local server status code: $($response.StatusCode)"
  }
} catch {
  throw "Local server is listening on $localUrl, but the site could not be loaded. $($_.Exception.Message)"
}

$stamp = Get-Date -Format "yyyyMMddHHmmss"
$stdout = Join-Path $env:TEMP "codx-localhostrun-$stamp.out.log"
$stderr = Join-Path $env:TEMP "codx-localhostrun-$stamp.err.log"
$sshArgs = "-o StrictHostKeyChecking=no -o ServerAliveInterval=30 -R 80:$HostName`:$Port nokey@localhost.run"

$tunnelProcess = Start-Process `
  -FilePath $Ssh.Source `
  -ArgumentList $sshArgs `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdout `
  -RedirectStandardError $stderr `
  -PassThru

$publicUrl = $null

for ($attempt = 0; $attempt -lt 20; $attempt++) {
  Start-Sleep -Seconds 1

  $output = ""
  if (Test-Path $stdout) {
    $output += Get-Content $stdout -Raw -ErrorAction SilentlyContinue
  }
  if (Test-Path $stderr) {
    $output += "`n"
    $output += Get-Content $stderr -Raw -ErrorAction SilentlyContinue
  }

  $match = [regex]::Match($output, "https://[a-zA-Z0-9.-]+\.lhr\.life")
  if ($match.Success) {
    $publicUrl = $match.Value
    break
  }

  if ($tunnelProcess.HasExited) {
    throw "localhost.run tunnel exited before a public URL was created. Output:`n$output"
  }
}

if (-not $publicUrl) {
  throw "Timed out waiting for localhost.run to provide a public URL. Logs: $stdout $stderr"
}

Write-Host ""
Write-Host "CodX temporary preview is running." -ForegroundColor Green
Write-Host ""
Write-Host "Local URL:  $localUrl"
Write-Host "Public URL: $publicUrl"
Write-Host ""
Write-Host "Local server PID: $serverPid"
Write-Host "Tunnel PID:       $($tunnelProcess.Id)"
Write-Host ""
Write-Host "Stop tunnel:"
Write-Host "  Stop-Process -Id $($tunnelProcess.Id)"
Write-Host ""
if ($startedServer) {
  Write-Host "Stop local server:"
  Write-Host "  Stop-Process -Id $serverPid"
} else {
  Write-Host "Local server was already running. Stop it from the app that started it, or use:"
  Write-Host "  Stop-Process -Id $serverPid"
}
Write-Host ""
