#!/bin/bash
# Cursor Startup Sound - Cross-platform installer (Linux/macOS)
set -e

YOUTUBE_URL="https://www.youtube.com/watch?v=EWMQI8dIP-4"
AUDIO_START=17.5
AUDIO_DURATION=1.1

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)  PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *)       echo "Unsupported OS: $OS"; exit 1;;
esac

echo "=== Cursor Startup Sound Installer ==="
echo "Platform: $PLATFORM"
echo ""

# Set paths based on platform
if [ "$PLATFORM" = "linux" ]; then
    SOUNDS_DIR="$HOME/.local/share/sounds"
    BIN_DIR="$HOME/.local/bin"
    APPS_DIR="$HOME/.local/share/applications"
    CURSOR_PATH="/usr/share/cursor/cursor"
    PLAY_CMD="aplay"
else
    SOUNDS_DIR="$HOME/Library/Sounds"
    BIN_DIR="$HOME/.local/bin"
    CURSOR_PATH="/Applications/Cursor.app/Contents/MacOS/Cursor"
    PLAY_CMD="afplay"
fi

# Create directories
mkdir -p "$SOUNDS_DIR" "$BIN_DIR"
[ "$PLATFORM" = "linux" ] && mkdir -p "$APPS_DIR"

# Check dependencies
echo "[1/5] Checking dependencies..."
if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg not found. Please install it first:"
    [ "$PLATFORM" = "linux" ] && echo "  sudo apt install ffmpeg"
    [ "$PLATFORM" = "macos" ] && echo "  brew install ffmpeg"
    exit 1
fi

# Download yt-dlp
echo "[2/5] Downloading yt-dlp..."
if [ "$PLATFORM" = "macos" ]; then
    curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o "$BIN_DIR/yt-dlp"
else
    curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$BIN_DIR/yt-dlp"
fi
chmod +x "$BIN_DIR/yt-dlp"

# Download audio
echo "[3/5] Downloading audio from YouTube..."
"$BIN_DIR/yt-dlp" -q -x --audio-format wav -o "/tmp/cursor-sound-full.%(ext)s" "$YOUTUBE_URL"

# Cut audio
echo "[4/5] Processing audio..."
ffmpeg -y -i /tmp/cursor-sound-full.wav -ss "$AUDIO_START" -t "$AUDIO_DURATION" "$SOUNDS_DIR/cursor-startup.wav" 2>/dev/null
rm -f /tmp/cursor-sound-full.wav

# Create wrapper script
echo "[5/5] Creating wrapper..."
cat > "$BIN_DIR/cursor-with-sound" << EOF
#!/bin/bash
$PLAY_CMD "$SOUNDS_DIR/cursor-startup.wav" 2>/dev/null &
exec "$CURSOR_PATH" "\$@"
EOF
chmod +x "$BIN_DIR/cursor-with-sound"

# Platform-specific integration
if [ "$PLATFORM" = "linux" ]; then
    cat > "$APPS_DIR/cursor.desktop" << EOF
[Desktop Entry]
Name=Cursor
Comment=The AI Code Editor.
GenericName=Text Editor
Exec=$BIN_DIR/cursor-with-sound %F
Icon=co.anysphere.cursor
Type=Application
StartupNotify=false
StartupWMClass=Cursor
Categories=TextEditor;Development;IDE;
MimeType=application/x-cursor-workspace;
Keywords=cursor;
EOF
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
    echo ""
    echo "Done! Cursor will now play a sound when opened from the app menu."
else
    echo ""
    echo "Done! To use, run: $BIN_DIR/cursor-with-sound"
    echo ""
    echo "To replace the default Cursor app, run:"
    echo "  sudo ln -sf $BIN_DIR/cursor-with-sound /usr/local/bin/cursor"
fi

echo ""
echo "Test with: $BIN_DIR/cursor-with-sound"
