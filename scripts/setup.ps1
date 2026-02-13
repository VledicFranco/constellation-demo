# One-time setup script for the Constellation Demo (Windows)
# Builds the TS SDK tarball and prepares the Docker build context

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$EngineDir = Join-Path (Split-Path -Parent $ProjectDir) "constellation-engine"

Write-Host "=== Constellation Demo Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build TS SDK tarball for Docker
Write-Host "[1/3] Building TypeScript SDK tarball..." -ForegroundColor Yellow
$TsSdkDir = Join-Path $EngineDir "sdks\typescript"
if (Test-Path $TsSdkDir) {
    Push-Location $TsSdkDir
    npm pack
    $Tarball = Get-ChildItem "constellation-engine-provider-sdk-*.tgz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Copy-Item $Tarball.FullName (Join-Path $ProjectDir "provider-ts\")
    Write-Host "  Copied $($Tarball.Name) to provider-ts/" -ForegroundColor Green
    Pop-Location
} else {
    Write-Host "  WARNING: constellation-engine\sdks\typescript not found." -ForegroundColor Red
    Write-Host "  Docker build for provider-ts will fail without the SDK tarball."
}

# Step 2: Install TS provider dependencies (local dev)
Write-Host "[2/3] Installing provider-ts dependencies..." -ForegroundColor Yellow
Push-Location (Join-Path $ProjectDir "provider-ts")
if (Test-Path "package.json") {
    npm install
    Write-Host "  Dependencies installed." -ForegroundColor Green
}
Pop-Location

# Step 3: Verify Docker
Write-Host "[3/3] Checking Docker..." -ForegroundColor Yellow
try {
    docker --version
    Write-Host "  Docker is available." -ForegroundColor Green
} catch {
    Write-Host "  WARNING: Docker not found. Install Docker to run the demo." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start the demo:"
Write-Host "  docker compose up --build"
Write-Host ""
Write-Host "Or for local development:"
Write-Host "  cd provider-ts; npm run dev"
