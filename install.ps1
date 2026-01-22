# Cursor Startup Sound - Windows Installer
# https://github.com/JohnHolz/cursor-startup-sound
# Run: irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$VERSION = "1.0.0"
$REPO_URL = "https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

# Set paths
$SOUNDS_DIR = "$env:LOCALAPPDATA\CursorStartupSound"
$CONFIG_FILE = "$SOUNDS_DIR\version.txt"
$CURSOR_PATH = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"

# Alternative Cursor paths
if (-not (Test-Path $CURSOR_PATH)) {
    $CURSOR_PATH = "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
}

# Check for uninstall flag
if ($args -contains "--uninstall" -or $args -contains "-u") {
    Write-Host "Uninstalling Cursor Startup Sound..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $SOUNDS_DIR -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\Cursor (with sound).lnk" -ErrorAction SilentlyContinue
    Write-Host "Done!" -ForegroundColor Green
    exit 0
}

# Check existing installation
$ACTION = "Installing"
if (Test-Path $CONFIG_FILE) {
    $OLD_VERSION = Get-Content $CONFIG_FILE
    $ACTION = "Updating ($OLD_VERSION -> $VERSION)"
}

Write-Host "=== Cursor Startup Sound v$VERSION ===" -ForegroundColor Cyan
Write-Host "$ACTION for Windows"
Write-Host ""

if (-not (Test-Path $CURSOR_PATH)) {
    Write-Host "Error: Cursor not found. Please install Cursor first." -ForegroundColor Red
    exit 1
}

# Create directory
New-Item -ItemType Directory -Force -Path $SOUNDS_DIR | Out-Null

# Download audio files
Write-Host "[1/3] Downloading audio files..."
Invoke-WebRequest -Uri "$REPO_URL/cursor-startup.wav" -OutFile "$SOUNDS_DIR\cursor-startup.wav"
Invoke-WebRequest -Uri "$REPO_URL/cursor-shutdown.wav" -OutFile "$SOUNDS_DIR\cursor-shutdown.wav"

# Create wrapper script
Write-Host "[2/3] Creating wrapper..."
$wrapperPath = "$SOUNDS_DIR\cursor-with-sound.bat"
$wrapperContent = @"
@echo off
start /b powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\cursor-startup.wav').PlaySync()"
"$CURSOR_PATH" %*
powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\cursor-shutdown.wav').PlaySync()"
"@
Set-Content -Path $wrapperPath -Value $wrapperContent

# Save version
Set-Content -Path $CONFIG_FILE -Value $VERSION

# Create shortcut on Desktop
Write-Host "[3/3] Creating shortcut..."
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cursor (with sound).lnk")
$Shortcut.TargetPath = $wrapperPath
$Shortcut.IconLocation = $CURSOR_PATH
$Shortcut.Save()

Write-Host ""
Write-Host "Done! Cursor will now play sounds when opened and closed." -ForegroundColor Green
Write-Host ""
Write-Host "A shortcut 'Cursor (with sound)' was created on your Desktop."
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  Update:    irm $REPO_URL/install.ps1 | iex"
Write-Host "  Uninstall: iex `"& { `$(irm $REPO_URL/install.ps1) } --uninstall`""
