# Cursor Startup Sound - Windows Installer
# https://github.com/JohnHolz/cursor-startup-sound
# Run: irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$VERSION = "1.1.0"
$REPO_URL = "https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

# Set paths
$SOUNDS_DIR = "$env:LOCALAPPDATA\CursorStartupSound"
$CONFIG_FILE = "$SOUNDS_DIR\version.txt"
$CURSOR_HOOKS_DIR = "$env:USERPROFILE\.cursor\hooks"
$HOOKS_FILE = "$env:USERPROFILE\.cursor\hooks.json"
$CURSOR_PATH = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"

# Alternative Cursor paths
if (-not (Test-Path $CURSOR_PATH)) {
    $CURSOR_PATH = "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
}

# Check for uninstall flag
if ($args -contains "--uninstall" -or $args -contains "-u") {
    Write-Host "Uninstalling Cursor Startup Sound..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $SOUNDS_DIR -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $CURSOR_HOOKS_DIR -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\Cursor (with sound).lnk" -ErrorAction SilentlyContinue
    Write-Host "Note: You may need to manually edit ~/.cursor/hooks.json to remove the beforeSubmitPrompt hook"
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

# Create directories
New-Item -ItemType Directory -Force -Path $SOUNDS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $CURSOR_HOOKS_DIR | Out-Null

# Download audio files
Write-Host "[1/4] Downloading audio files..."
Invoke-WebRequest -Uri "$REPO_URL/cursor-startup.wav" -OutFile "$SOUNDS_DIR\cursor-startup.wav"
Invoke-WebRequest -Uri "$REPO_URL/cursor-shutdown.wav" -OutFile "$SOUNDS_DIR\cursor-shutdown.wav"
Invoke-WebRequest -Uri "$REPO_URL/cursor-send.wav" -OutFile "$SOUNDS_DIR\cursor-send.wav"

# Create wrapper script
Write-Host "[2/4] Creating wrapper..."
$wrapperPath = "$SOUNDS_DIR\cursor-with-sound.bat"
$wrapperContent = @"
@echo off
start /b powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\cursor-startup.wav').PlaySync()"
"$CURSOR_PATH" %*
powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\cursor-shutdown.wav').PlaySync()"
"@
Set-Content -Path $wrapperPath -Value $wrapperContent

# Create hook script for send sound
Write-Host "[3/4] Configuring send sound hook..."
$hookScript = "$CURSOR_HOOKS_DIR\play-send-sound.ps1"
$hookContent = @"
# Plays sound when sending message to AI
`$player = New-Object Media.SoundPlayer "$SOUNDS_DIR\cursor-send.wav"
`$player.Play()
Write-Output '{"continue": true}'
"@
Set-Content -Path $hookScript -Value $hookContent

# Create batch wrapper for hook (Cursor needs executable)
$hookBat = "$CURSOR_HOOKS_DIR\play-send-sound.bat"
$hookBatContent = @"
@echo off
powershell -WindowStyle Hidden -File "$hookScript"
"@
Set-Content -Path $hookBat -Value $hookBatContent

# Create or update hooks.json
if (-not (Test-Path $HOOKS_FILE)) {
    $hooksJson = @"
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {
        "command": "$hookBat"
      }
    ]
  }
}
"@
    Set-Content -Path $HOOKS_FILE -Value $hooksJson
} else {
    if (-not (Select-String -Path $HOOKS_FILE -Pattern "play-send-sound" -Quiet)) {
        Write-Host "Note: ~/.cursor/hooks.json exists. Please add manually:" -ForegroundColor Yellow
        Write-Host "  `"beforeSubmitPrompt`": [{`"command`": `"$hookBat`"}]"
    }
}

# Save version
Set-Content -Path $CONFIG_FILE -Value $VERSION

# Create shortcut on Desktop
Write-Host "[4/4] Creating shortcut..."
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cursor (with sound).lnk")
$Shortcut.TargetPath = $wrapperPath
$Shortcut.IconLocation = $CURSOR_PATH
$Shortcut.Save()

Write-Host ""
Write-Host "Done! Cursor sounds configured:" -ForegroundColor Green
Write-Host "  - Startup sound (when opening)"
Write-Host "  - Shutdown sound (when closing)"
Write-Host "  - Send sound (when sending message to AI)"
Write-Host ""
Write-Host "Note: Restart Cursor to activate the send sound hook."
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  Update:    irm $REPO_URL/install.ps1 | iex"
Write-Host "  Uninstall: & ([scriptblock]::Create((irm $REPO_URL/install.ps1))) --uninstall"
