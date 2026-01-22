#!/bin/bash
# Cursor Startup Sound - Cross-platform installer (Linux/macOS)
set -e

REPO_URL="https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

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
    PLAY_CMD="aplay"
else
    SOUNDS_DIR="$HOME/Library/Sounds"
    BIN_DIR="$HOME/.local/bin"
    PLAY_CMD="afplay"
fi

# Create directories
mkdir -p "$SOUNDS_DIR" "$BIN_DIR"
[ "$PLATFORM" = "linux" ] && mkdir -p "$APPS_DIR"

# Download audio files
echo "[1/2] Downloading audio files..."
curl -sL "$REPO_URL/cursor-startup.wav" -o "$SOUNDS_DIR/cursor-startup.wav"
curl -sL "$REPO_URL/cursor-shutdown.wav" -o "$SOUNDS_DIR/cursor-shutdown.wav"

# Create wrapper script with fallback paths
echo "[2/2] Creating wrapper..."
if [ "$PLATFORM" = "linux" ]; then
    cat > "$BIN_DIR/cursor-with-sound" << 'EOF'
#!/bin/bash
SOUNDS_DIR="$HOME/.local/share/sounds"

# Play startup sound
aplay "$SOUNDS_DIR/cursor-startup.wav" 2>/dev/null &

# Find Cursor executable (supports updates/path changes)
CURSOR_BIN=""
for path in \
    /usr/share/cursor/cursor \
    /usr/bin/cursor \
    /opt/cursor/cursor \
    /opt/Cursor/cursor \
    "$HOME/.local/bin/cursor" \
    "$HOME/Applications/cursor" \
    "$(which cursor 2>/dev/null)"
do
    if [ -x "$path" ] && [ "$(realpath "$path" 2>/dev/null)" != "$(realpath "$0")" ]; then
        CURSOR_BIN="$path"
        break
    fi
done

if [ -z "$CURSOR_BIN" ]; then
    echo "Error: Cursor not found. Please reinstall Cursor."
    exit 1
fi

# Run Cursor and wait for it to exit
"$CURSOR_BIN" "$@"

# Play shutdown sound
aplay "$SOUNDS_DIR/cursor-shutdown.wav" 2>/dev/null
EOF
else
    cat > "$BIN_DIR/cursor-with-sound" << 'EOF'
#!/bin/bash
SOUNDS_DIR="$HOME/Library/Sounds"

# Play startup sound
afplay "$SOUNDS_DIR/cursor-startup.wav" 2>/dev/null &

# Find Cursor executable
CURSOR_BIN=""
for path in \
    "/Applications/Cursor.app/Contents/MacOS/Cursor" \
    "$HOME/Applications/Cursor.app/Contents/MacOS/Cursor"
do
    if [ -x "$path" ]; then
        CURSOR_BIN="$path"
        break
    fi
done

if [ -z "$CURSOR_BIN" ]; then
    echo "Error: Cursor not found. Please reinstall Cursor."
    exit 1
fi

# Run Cursor and wait for it to exit
"$CURSOR_BIN" "$@"

# Play shutdown sound
afplay "$SOUNDS_DIR/cursor-shutdown.wav" 2>/dev/null
EOF
fi
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
    echo "Done! Cursor will now play sounds when opened and closed."
else
    echo ""
    echo "Done! To use, run: $BIN_DIR/cursor-with-sound"
    echo ""
    echo "To replace the default Cursor command, run:"
    echo "  sudo ln -sf $BIN_DIR/cursor-with-sound /usr/local/bin/cursor"
fi

echo ""
echo "Test with: $BIN_DIR/cursor-with-sound"
