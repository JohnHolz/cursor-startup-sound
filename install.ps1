# Cursor Startup Sound - Windows Installer
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$YOUTUBE_URL = "https://www.youtube.com/watch?v=EWMQI8dIP-4"
$AUDIO_START = 17.5
$AUDIO_DURATION = 1.1

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

# Create directories
New-Item -ItemType Directory -Force -Path $SOUNDS_DIR | Out-Null

# Check for ffmpeg
Write-Host "[1/5] Checking dependencies..."
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "Error: ffmpeg not found. Please install it first:" -ForegroundColor Red
    Write-Host "  winget install ffmpeg"
    Write-Host "  or download from: https://ffmpeg.org/download.html"
    exit 1
}

# Download yt-dlp
Write-Host "[2/5] Downloading yt-dlp..."
$ytdlpPath = "$SOUNDS_DIR\yt-dlp.exe"
Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytdlpPath

# Download audio
Write-Host "[3/5] Downloading audio from YouTube..."
$tempAudio = "$env:TEMP\cursor-sound-full.wav"
& $ytdlpPath -q -x --audio-format wav -o "$env:TEMP\cursor-sound-full.%(ext)s" $YOUTUBE_URL

# Cut audio
Write-Host "[4/5] Processing audio..."
$outputAudio = "$SOUNDS_DIR\cursor-startup.wav"
& ffmpeg -y -i $tempAudio -ss $AUDIO_START -t $AUDIO_DURATION $outputAudio 2>$null
Remove-Item $tempAudio -ErrorAction SilentlyContinue

# Create wrapper script (batch file)
Write-Host "[5/5] Creating wrapper..."
$wrapperPath = "$SOUNDS_DIR\cursor-with-sound.bat"
$wrapperContent = @"
@echo off
start /b powershell -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$outputAudio').PlaySync()"
start "" "$CURSOR_PATH" %*
"@
Set-Content -Path $wrapperPath -Value $wrapperContent

# Create PowerShell wrapper (alternative)
$psWrapperPath = "$SOUNDS_DIR\cursor-with-sound.ps1"
$psWrapperContent = @"
`$sound = New-Object Media.SoundPlayer "$outputAudio"
`$sound.Play()
Start-Process "$CURSOR_PATH" -ArgumentList `$args
"@
Set-Content -Path $psWrapperPath -Value $psWrapperContent

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
Write-Host ""
Write-Host "Files created:"
Write-Host "  Audio: $outputAudio"
Write-Host "  Wrapper: $wrapperPath"
Write-Host ""
Write-Host "To pin to taskbar, right-click the desktop shortcut and select 'Pin to taskbar'"
