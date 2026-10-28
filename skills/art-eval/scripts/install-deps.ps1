param(
  [ValidateSet("ffmpeg", "yt-dlp")]
  [string[]]$Dependency
)

$ErrorActionPreference = "Stop"

if (-not $Dependency -or $Dependency.Count -eq 0) {
  $Dependency = @("ffmpeg", "yt-dlp")
}

function Test-Command {
  param([string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Command "winget")) {
  Write-Error "winget is required. Install App Installer from Microsoft Store, then retry."
}

$missing = @()
foreach ($dep in $Dependency) {
  if ($dep -eq "ffmpeg" -and -not (Test-Command "ffmpeg")) {
    $missing += "ffmpeg"
  }
  if ($dep -eq "yt-dlp" -and -not (Test-Command "yt-dlp")) {
    $missing += "yt-dlp"
  }
}

if ($missing.Count -eq 0) {
  Write-Host "art-eval dependencies are already installed."
  exit 0
}

Write-Host "Installing missing art-eval dependencies: $($missing -join ', ')"

foreach ($dep in $missing) {
  if ($dep -eq "ffmpeg") {
    winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
  }
  elseif ($dep -eq "yt-dlp") {
    winget install --id yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
  }
}

$stillMissing = @()
foreach ($dep in $Dependency) {
  if ($dep -eq "ffmpeg" -and -not (Test-Command "ffmpeg")) {
    $stillMissing += "ffmpeg"
  }
  if ($dep -eq "yt-dlp" -and -not (Test-Command "yt-dlp")) {
    $stillMissing += "yt-dlp"
  }
}

if ($stillMissing.Count -gt 0) {
  Write-Error "Install finished but these commands are still not on PATH: $($stillMissing -join ', '). Restart the terminal or add the install directory to PATH, then retry."
}

Write-Host "Installed art-eval dependencies successfully."
