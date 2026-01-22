# Cursor Startup Sound - Windows Installer
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$REPO_URL = "https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

Write-Host "=== Cursor Startup Sound Installer ===" -ForegroundColor Cyan
Write-Host "Platform: Windows"
Write-Host ""

# Set paths
$SOUNDS_DIR = "$env:LOCALAPPDATA\CursorStartupSound"
$CURSOR_PATH = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"

# Alternative Cursor paths
if (-not (Test-Path $CURSOR_PATH)) {
    $CURSOR_PATH = "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
}
if (-not (Test-Path $CURSOR_PATH)) {
    Write-Host "Error: Cursor not found. Please install Cursor first." -ForegroundColor Red
    exit 1
}

# Create directory
New-Item -ItemType Directory -Force -Path $SOUNDS_DIR | Out-Null

# Download audio files
Write-Host "[1/2] Downloading audio files..."
Invoke-WebRequest -Uri "$REPO_URL/cursor-startup.wav" -OutFile "$SOUNDS_DIR\cursor-startup.wav"
Invoke-WebRequest -Uri "$REPO_URL/cursor-shutdown.wav" -OutFile "$SOUNDS_DIR\cursor-shutdown.wav"

# Create wrapper script
Write-Host "[2/2] Creating wrapper..."
$wrapperPath = "$SOUNDS_DIR\cursor-with-sound.bat"
$wrapperContent = @"
@echo off
start /b powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\cursor-startup.wav').PlaySync()"
"$CURSOR_PATH" %*
powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\cursor-shutdown.wav').PlaySync()"
"@
Set-Content -Path $wrapperPath -Value $wrapperContent

# Create shortcut on Desktop
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cursor (with sound).lnk")
$Shortcut.TargetPath = $wrapperPath
$Shortcut.IconLocation = $CURSOR_PATH
$Shortcut.Save()

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
Write-Host "A shortcut 'Cursor (with sound)' was created on your Desktop."
Write-Host "Cursor will now play sounds when opened and closed."
Write-Host ""
Write-Host "To pin to taskbar, right-click the shortcut and select 'Pin to taskbar'"
