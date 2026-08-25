$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $root "frontend"
$backendDir = Join-Path $root "backend"

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath;$env:Path"

$env:GOCACHE = Join-Path $root ".gocache"
$env:GOMODCACHE = Join-Path $root ".gomodcache"

Write-Host "[1/2] Building frontend..."
Push-Location $frontendDir
try {
  npm run build
  if ($LASTEXITCODE -ne 0) {
    throw "Frontend build failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Host "[2/2] Building backend with embedded frontend..."
Push-Location $backendDir
try {
  go build -tags embed -o sub2api.exe ./cmd/server
  if ($LASTEXITCODE -ne 0) {
    throw "Backend build failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Host "Build complete: backend\sub2api.exe"
