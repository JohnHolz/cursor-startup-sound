#!/bin/bash
# Cursor Startup Sound - Cross-platform installer (Linux/macOS)
# https://github.com/JohnHolz/cursor-startup-sound
set -e

VERSION="1.2.0"
REPO_URL="https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)  PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *)       echo "Unsupported OS: $OS"; exit 1;;
esac

# Set paths based on platform
if [ "$PLATFORM" = "linux" ]; then
    SOUNDS_DIR="$HOME/.local/share/sounds"
    BIN_DIR="$HOME/.local/bin"
    APPS_DIR="$HOME/.local/share/applications"
    CONFIG_DIR="$HOME/.config/cursor-startup-sound"
    CURSOR_HOOKS_DIR="$HOME/.cursor/hooks"
    PLAY_CMD="aplay"
else
    SOUNDS_DIR="$HOME/Library/Sounds"
    BIN_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME/.config/cursor-startup-sound"
    CURSOR_HOOKS_DIR="$HOME/.cursor/hooks"
    PLAY_CMD="afplay"
fi

# Check for uninstall flag
if [ "$1" = "--uninstall" ] || [ "$1" = "-u" ]; then
    echo "Uninstalling Cursor Startup Sound..."
    rm -f "$SOUNDS_DIR/cursor-startup.wav" "$SOUNDS_DIR/cursor-shutdown.wav" "$SOUNDS_DIR/cursor-send.wav"
    rm -f "$BIN_DIR/cursor-with-sound"
    rm -f "$CURSOR_HOOKS_DIR/play-send-sound.sh"
    rm -rf "$CONFIG_DIR"
    if [ "$PLATFORM" = "linux" ]; then
        rm -f "$APPS_DIR/cursor.desktop"
    else
        # Remove macOS wrapper app
        rm -rf "$HOME/Applications/Cursor with Sound.app"
    fi
    # Remove hook from hooks.json if it exists
    if [ -f "$HOME/.cursor/hooks.json" ]; then
        # Simple removal - user may need to clean up manually if they have other hooks
        echo "Note: You may need to manually edit ~/.cursor/hooks.json to remove the beforeSubmitPrompt hook"
    fi
    echo "Done!"
    exit 0
fi

# Check existing installation
ACTION="Installing"
if [ -f "$CONFIG_DIR/version" ]; then
    OLD_VERSION=$(cat "$CONFIG_DIR/version")
    ACTION="Updating ($OLD_VERSION -> $VERSION)"
fi

echo "=== Cursor Startup Sound v$VERSION ==="
echo "$ACTION for $PLATFORM"
echo ""

# Create directories
mkdir -p "$SOUNDS_DIR" "$BIN_DIR" "$CONFIG_DIR" "$CURSOR_HOOKS_DIR"
if [ "$PLATFORM" = "linux" ]; then
    mkdir -p "$APPS_DIR"
else
    mkdir -p "$HOME/Applications"
fi

# Download audio files
echo "[1/4] Downloading audio files..."
curl -sL "$REPO_URL/cursor-startup.wav" -o "$SOUNDS_DIR/cursor-startup.wav"
curl -sL "$REPO_URL/cursor-shutdown.wav" -o "$SOUNDS_DIR/cursor-shutdown.wav"
curl -sL "$REPO_URL/cursor-send.wav" -o "$SOUNDS_DIR/cursor-send.wav"

# Create wrapper script with fallback paths
echo "[2/4] Creating wrapper..."
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

# Create hook script for send sound
echo "[3/4] Configuring send sound hook..."
cat > "$CURSOR_HOOKS_DIR/play-send-sound.sh" << EOF
#!/bin/bash
# Plays sound when sending message to AI
cat > /dev/null  # Read stdin (required by Cursor)
$PLAY_CMD "$SOUNDS_DIR/cursor-send.wav" 2>/dev/null &
echo '{"continue": true}'
EOF
chmod +x "$CURSOR_HOOKS_DIR/play-send-sound.sh"

# Create or update hooks.json
HOOKS_FILE="$HOME/.cursor/hooks.json"
if [ ! -f "$HOOKS_FILE" ]; then
    cat > "$HOOKS_FILE" << EOF
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      {
        "command": "$CURSOR_HOOKS_DIR/play-send-sound.sh"
      }
    ]
  }
}
EOF
else
    # Check if our hook is already there
    if ! grep -q "play-send-sound.sh" "$HOOKS_FILE"; then
        echo "Note: ~/.cursor/hooks.json exists. Please add manually:"
        echo "  \"beforeSubmitPrompt\": [{\"command\": \"$CURSOR_HOOKS_DIR/play-send-sound.sh\"}]"
    fi
fi

# Save version
echo "$VERSION" > "$CONFIG_DIR/version"

# Platform-specific integration
echo "[4/4] Configuring system..."
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
else
    # macOS: Create wrapper .app bundle
    WRAPPER_APP="$HOME/Applications/Cursor with Sound.app"
    mkdir -p "$WRAPPER_APP/Contents/MacOS"
    mkdir -p "$WRAPPER_APP/Contents/Resources"

    # Find original Cursor.app to copy icon
    ORIGINAL_APP=""
    for app_path in "/Applications/Cursor.app" "$HOME/Applications/Cursor.app"; do
        if [ -d "$app_path" ]; then
            ORIGINAL_APP="$app_path"
            break
        fi
    done

    # Copy icon from original Cursor.app
    if [ -n "$ORIGINAL_APP" ] && [ -f "$ORIGINAL_APP/Contents/Resources/Cursor.icns" ]; then
        cp "$ORIGINAL_APP/Contents/Resources/Cursor.icns" "$WRAPPER_APP/Contents/Resources/AppIcon.icns"
    fi

    # Create Info.plist
    cat > "$WRAPPER_APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cursor-startup-sound.wrapper</string>
    <key>CFBundleName</key>
    <string>Cursor with Sound</string>
    <key>CFBundleDisplayName</key>
    <string>Cursor with Sound</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

    # Create launcher script
    cat > "$WRAPPER_APP/Contents/MacOS/launcher" << 'EOF'
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
    osascript -e 'display dialog "Cursor not found. Please install Cursor first." buttons {"OK"} default button "OK" with icon stop'
    exit 1
fi

# Run Cursor and wait for it to exit
"$CURSOR_BIN" "$@"

# Play shutdown sound
afplay "$SOUNDS_DIR/cursor-shutdown.wav" 2>/dev/null
EOF
    chmod +x "$WRAPPER_APP/Contents/MacOS/launcher"

    # Touch the app to update Finder/Spotlight
    touch "$WRAPPER_APP"

    echo ""
    echo "macOS app created: ~/Applications/Cursor with Sound.app"
    echo "You can drag it to your Dock for easy access!"
fi

echo ""
echo "Done! Cursor sounds configured:"
echo "  - Startup sound (when opening)"
echo "  - Shutdown sound (when closing)"
echo "  - Send sound (when sending message to AI)"
echo ""
echo "Note: Restart Cursor to activate the send sound hook."
echo ""
echo "Commands:"
echo "  Update:    curl -fsSL $REPO_URL/install.sh | bash"
echo "  Uninstall: curl -fsSL $REPO_URL/install.sh | bash -s -- --uninstall"
