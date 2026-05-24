#Requires -Version 5.1
param(
    [string]$Version  = "0.0.2.G",
    [string]$IsccPath = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $IsccPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $IsccPath = $c; break } }
}
if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
    Write-Error "ISCC.exe not found. Install: winget install JRSoftware.InnoSetup"
}

$ScriptDir   = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptDir -Parent
$IssFile     = Join-Path $ScriptDir "4H-Unfolder.iss"
$PublishDir  = Join-Path $ProjectRoot "publish\v$Version"
$DistDir     = Join-Path $ProjectRoot "dist"
$ExpectedOut = Join-Path $DistDir "4H-Unfolder-Setup-v${Version}.exe"

if (-not (Test-Path $IssFile))    { Write-Error "Script not found: $IssFile" }
if (-not (Test-Path $PublishDir)) { Write-Error "Publish dir not found: $PublishDir  (run dotnet publish first)" }
if (-not (Test-Path (Join-Path $PublishDir "4H-Unfolder.exe"))) { Write-Error "4H-Unfolder.exe not found in $PublishDir" }
if (-not (Test-Path $DistDir))    { New-Item -ItemType Directory -Path $DistDir | Out-Null }

Write-Host ""
Write-Host "=== 4H-Unfolder Installer Build ===" -ForegroundColor Cyan
Write-Host "  ISCC   : $IsccPath"
Write-Host "  Source : $PublishDir"
Write-Host "  Output : $ExpectedOut"
Write-Host ""

$startTime = Get-Date
& $IsccPath $IssFile
if ($LASTEXITCODE -ne 0) { Write-Error "ISCC.exe failed (exit $LASTEXITCODE)" }

if (Test-Path $ExpectedOut) {
    $item    = Get-Item $ExpectedOut
    $sizeMB  = [math]::Round($item.Length / 1048576, 1)
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
    Write-Host ""
    Write-Host ("Done in {0}s -- {1} MB" -f $elapsed, $sizeMB) -ForegroundColor Green
    Write-Host $ExpectedOut -ForegroundColor Green
} else {
    Write-Host "ERROR: output not found: $ExpectedOut" -ForegroundColor Red
    exit 1
}