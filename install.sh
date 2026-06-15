#!/bin/bash
# WC3 Editor Sounds - Cross-platform installer (Linux/macOS)
# Plays Warcraft-3-style sounds in Cursor, VS Code and Claude Code.
# https://github.com/JohnHolz/cursor-startup-sound
set -e

VERSION="2.0.0"
REPO_URL="https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
THEME="${WC3_THEME:-}"
DO_UNINSTALL=0
while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall|-u) DO_UNINSTALL=1 ;;
        --theme)        THEME="$2"; shift ;;
        --theme=*)      THEME="${1#*=}" ;;
        --help|-h)
            echo "WC3 Editor Sounds installer v$VERSION"
            echo ""
            echo "Usage: install.sh [--theme human|orc] [--uninstall]"
            echo ""
            echo "  --theme human|orc   Sound theme (default: human). Or set WC3_THEME."
            echo "  --uninstall, -u     Remove everything this installer created."
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)  PLATFORM="linux";;
    Darwin*) PLATFORM="macos";;
    *)       echo "Unsupported OS: $OS"; exit 1;;
esac

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/wc3-sounds"
CURSOR_HOOKS_DIR="$HOME/.cursor/hooks"
CURSOR_HOOKS_FILE="$HOME/.cursor/hooks.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_HOOK_DIR="$CONFIG_DIR/claude-hooks"

if [ "$PLATFORM" = "linux" ]; then
    SOUNDS_DIR="$HOME/.local/share/wc3-sounds"
    APPS_DIR="$HOME/.local/share/applications"
    PLAY_LINE='paplay "$1" 2>/dev/null || aplay "$1" 2>/dev/null'
else
    SOUNDS_DIR="$HOME/Library/Application Support/wc3-sounds"
    PLAY_LINE='afplay "$1" 2>/dev/null'
fi

# ---------------------------------------------------------------------------
# settings.json merge helper (Claude Code) — preserves existing user hooks
#   merge_claude add|remove
# Reads $CLAUDE_SETTINGS, adds/removes our 3 hooks, writes back.
# Returns 1 if no merger (python3/jq) is available so caller can print manual steps.
# ---------------------------------------------------------------------------
merge_claude() {
    local mode="$1"
    local map="{\"SessionStart\":\"$CLAUDE_HOOK_DIR/startup.sh\",\"UserPromptSubmit\":\"$CLAUDE_HOOK_DIR/send.sh\",\"Stop\":\"$CLAUDE_HOOK_DIR/shutdown.sh\"}"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$mode" "$CLAUDE_SETTINGS" "$map" <<'PYEOF'
import json, sys, os
mode, path, mapping = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except Exception:
    sys.exit(3)  # unparseable -> caller prints manual steps

if not isinstance(data, dict):
    sys.exit(3)

hooks = data.get("hooks") if isinstance(data.get("hooks"), dict) else {}

def is_ours(entry, cmd):
    return any(h.get("command") == cmd for h in entry.get("hooks", []) if isinstance(h, dict))

for event, cmd in mapping.items():
    arr = [e for e in hooks.get(event, []) if isinstance(e, dict) and not is_ours(e, cmd)]
    if mode == "add":
        arr.append({"hooks": [{"type": "command", "command": cmd}]})
    if arr:
        hooks[event] = arr
    elif event in hooks:
        del hooks[event]

if hooks:
    data["hooks"] = hooks
elif "hooks" in data:
    del data["hooks"]

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
        return $?
    elif command -v jq >/dev/null 2>&1; then
        local tmp; tmp="$(mktemp)"
        [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"
        if [ "$mode" = "add" ]; then
            jq --arg s "$CLAUDE_HOOK_DIR/startup.sh" \
               --arg p "$CLAUDE_HOOK_DIR/send.sh" \
               --arg d "$CLAUDE_HOOK_DIR/shutdown.sh" '
              .hooks //= {} |
              .hooks.SessionStart    = ((.hooks.SessionStart    // []) | map(select(any(.hooks[]?; .command==$s)|not))) + [{"hooks":[{"type":"command","command":$s}]}] |
              .hooks.UserPromptSubmit= ((.hooks.UserPromptSubmit // []) | map(select(any(.hooks[]?; .command==$p)|not))) + [{"hooks":[{"type":"command","command":$p}]}] |
              .hooks.Stop            = ((.hooks.Stop            // []) | map(select(any(.hooks[]?; .command==$d)|not))) + [{"hooks":[{"type":"command","command":$d}]}]
            ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
        else
            jq --arg s "$CLAUDE_HOOK_DIR/startup.sh" \
               --arg p "$CLAUDE_HOOK_DIR/send.sh" \
               --arg d "$CLAUDE_HOOK_DIR/shutdown.sh" '
              (.hooks.SessionStart)     |= (map(select(any(.hooks[]?; .command==$s)|not))) |
              (.hooks.UserPromptSubmit) |= (map(select(any(.hooks[]?; .command==$p)|not))) |
              (.hooks.Stop)             |= (map(select(any(.hooks[]?; .command==$d)|not)))
            ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
        fi
        return 0
    fi
    return 1  # no merger available
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [ "$DO_UNINSTALL" = "1" ]; then
    echo "Uninstalling WC3 Editor Sounds..."
    # Sounds (new + legacy v1 locations)
    rm -rf "$SOUNDS_DIR"
    rm -f "$HOME/.local/share/sounds/cursor-startup.wav" \
          "$HOME/.local/share/sounds/cursor-shutdown.wav" \
          "$HOME/.local/share/sounds/cursor-send.wav" 2>/dev/null || true
    rm -f "$HOME/Library/Sounds/cursor-startup.wav" \
          "$HOME/Library/Sounds/cursor-shutdown.wav" \
          "$HOME/Library/Sounds/cursor-send.wav" 2>/dev/null || true
    # Cursor wrapper + hook
    rm -f "$BIN_DIR/cursor-with-sound"
    rm -f "$CURSOR_HOOKS_DIR/play-send-sound.sh"
    if [ "$PLATFORM" = "linux" ]; then
        rm -f "$APPS_DIR/cursor.desktop"
    else
        rm -rf "$HOME/Applications/Cursor with Sound.app"
    fi
    # Claude Code hooks
    if [ -f "$CLAUDE_SETTINGS" ]; then
        if merge_claude remove; then
            echo "  Removed Claude Code hooks from settings.json"
        else
            echo "  Note: edit ~/.claude/settings.json to remove the wc3-sounds hooks (no python3/jq found)"
        fi
    fi
    # VS Code extension
    if command -v code >/dev/null 2>&1; then
        code --uninstall-extension johnholz.wc3-sounds >/dev/null 2>&1 || true
    fi
    rm -rf "$CONFIG_DIR"
    if [ -f "$CURSOR_HOOKS_FILE" ]; then
        echo "  Note: you may want to edit ~/.cursor/hooks.json to remove the beforeSubmitPrompt hook"
    fi
    echo "Done!"
    exit 0
fi

# ---------------------------------------------------------------------------
# Theme resolution
# ---------------------------------------------------------------------------
if [ -z "$THEME" ]; then
    if [ -t 0 ]; then
        echo "Choose a sound theme:"
        echo "  1) human (Peasant)"
        echo "  2) orc   (Peon)"
        printf "Theme [1]: "
        read -r choice
        case "$choice" in
            2|orc)  THEME="orc";;
            *)      THEME="human";;
        esac
    else
        THEME="human"
    fi
fi
case "$THEME" in
    human|orc) ;;
    *) echo "Invalid theme '$THEME' (use human or orc)"; exit 1;;
esac

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
ACTION="Installing"
if [ -f "$CONFIG_DIR/version" ]; then
    OLD_VERSION=$(cat "$CONFIG_DIR/version")
    ACTION="Updating ($OLD_VERSION -> $VERSION)"
fi

echo "=== WC3 Editor Sounds v$VERSION ==="
echo "$ACTION for $PLATFORM, theme: $THEME"
echo ""

mkdir -p "$SOUNDS_DIR" "$BIN_DIR" "$CONFIG_DIR" "$CURSOR_HOOKS_DIR" "$CLAUDE_HOOK_DIR"
[ "$PLATFORM" = "linux" ] && mkdir -p "$APPS_DIR" || mkdir -p "$HOME/Applications"

# --- 1. Download sounds for the chosen theme -------------------------------
echo "[1/5] Downloading $THEME sounds..."
for name in startup send shutdown; do
    curl -sL "$REPO_URL/sounds/$THEME/$name.wav" -o "$SOUNDS_DIR/$name.wav"
done

# --- 2. Cursor: wrapper (startup/shutdown) ---------------------------------
echo "[2/5] Configuring Cursor wrapper..."
if [ "$PLATFORM" = "linux" ]; then
    cat > "$BIN_DIR/cursor-with-sound" << EOF
#!/bin/bash
SOUNDS_DIR="$SOUNDS_DIR"
paplay "\$SOUNDS_DIR/startup.wav" 2>/dev/null || aplay "\$SOUNDS_DIR/startup.wav" 2>/dev/null &
CURSOR_BIN=""
for path in /usr/share/cursor/cursor /usr/bin/cursor /opt/cursor/cursor /opt/Cursor/cursor \\
    "\$HOME/.local/bin/cursor" "\$HOME/Applications/cursor" "\$(which cursor 2>/dev/null)"; do
    if [ -x "\$path" ] && [ "\$(realpath "\$path" 2>/dev/null)" != "\$(realpath "\$0")" ]; then
        CURSOR_BIN="\$path"; break
    fi
done
[ -z "\$CURSOR_BIN" ] && { echo "Error: Cursor not found."; exit 1; }
"\$CURSOR_BIN" "\$@"
paplay "\$SOUNDS_DIR/shutdown.wav" 2>/dev/null || aplay "\$SOUNDS_DIR/shutdown.wav" 2>/dev/null
EOF
else
    cat > "$BIN_DIR/cursor-with-sound" << EOF
#!/bin/bash
SOUNDS_DIR="$SOUNDS_DIR"
afplay "\$SOUNDS_DIR/startup.wav" 2>/dev/null &
CURSOR_BIN=""
for path in "/Applications/Cursor.app/Contents/MacOS/Cursor" "\$HOME/Applications/Cursor.app/Contents/MacOS/Cursor"; do
    [ -x "\$path" ] && { CURSOR_BIN="\$path"; break; }
done
[ -z "\$CURSOR_BIN" ] && { echo "Error: Cursor not found."; exit 1; }
"\$CURSOR_BIN" "\$@"
afplay "\$SOUNDS_DIR/shutdown.wav" 2>/dev/null
EOF
fi
chmod +x "$BIN_DIR/cursor-with-sound"

# --- 3. Cursor: send-sound hook -------------------------------------------
echo "[3/5] Configuring Cursor send hook..."
cat > "$CURSOR_HOOKS_DIR/play-send-sound.sh" << EOF
#!/bin/bash
cat > /dev/null  # drain stdin (required by Cursor)
SND="$SOUNDS_DIR/send.wav"
$( [ "$PLATFORM" = "linux" ] && echo 'paplay "$SND" 2>/dev/null || aplay "$SND" 2>/dev/null &' || echo 'afplay "$SND" 2>/dev/null &' )
echo '{"continue": true}'
EOF
chmod +x "$CURSOR_HOOKS_DIR/play-send-sound.sh"

if [ ! -f "$CURSOR_HOOKS_FILE" ]; then
    cat > "$CURSOR_HOOKS_FILE" << EOF
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      { "command": "$CURSOR_HOOKS_DIR/play-send-sound.sh" }
    ]
  }
}
EOF
elif ! grep -q "play-send-sound.sh" "$CURSOR_HOOKS_FILE"; then
    echo "  Note: ~/.cursor/hooks.json exists. Add manually under hooks:"
    echo "    \"beforeSubmitPrompt\": [{\"command\": \"$CURSOR_HOOKS_DIR/play-send-sound.sh\"}]"
fi

# --- 4. Claude Code: hook scripts + settings.json merge --------------------
echo "[4/5] Configuring Claude Code hooks..."
for evt in startup send shutdown; do
    cat > "$CLAUDE_HOOK_DIR/$evt.sh" << EOF
#!/bin/bash
cat > /dev/null 2>&1 || true   # drain stdin
SND="$SOUNDS_DIR/$evt.wav"
$( [ "$PLATFORM" = "linux" ] && echo '( paplay "$SND" 2>/dev/null || aplay "$SND" 2>/dev/null ) &' || echo 'afplay "$SND" 2>/dev/null &' )
exit 0
EOF
    chmod +x "$CLAUDE_HOOK_DIR/$evt.sh"
done
if merge_claude add; then
    echo "  Claude Code hooks installed (SessionStart / UserPromptSubmit / Stop)"
else
    echo "  Note: no python3/jq found. Add these to ~/.claude/settings.json under \"hooks\":"
    echo "    SessionStart -> $CLAUDE_HOOK_DIR/startup.sh"
    echo "    UserPromptSubmit -> $CLAUDE_HOOK_DIR/send.sh"
    echo "    Stop -> $CLAUDE_HOOK_DIR/shutdown.sh"
fi

# --- 5. VS Code: install the extension (covers startup/shutdown) ------------
echo "[5/5] Configuring VS Code..."
if command -v code >/dev/null 2>&1; then
    VSIX_TMP="$(mktemp --suffix=.vsix 2>/dev/null || mktemp)"
    if curl -fsSL "$REPO_URL/extension/wc3-sounds-$VERSION.vsix" -o "$VSIX_TMP" 2>/dev/null; then
        code --install-extension "$VSIX_TMP" --force >/dev/null 2>&1 \
            && echo "  VS Code extension installed." \
            || echo "  Could not auto-install the VS Code extension; install the .vsix manually."
        # set theme in VS Code user settings (best-effort)
        VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
        [ "$PLATFORM" = "macos" ] && VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
        if command -v python3 >/dev/null 2>&1 && [ -d "$(dirname "$VSCODE_SETTINGS")" ]; then
            python3 - "$VSCODE_SETTINGS" "$THEME" <<'PYEOF' 2>/dev/null || true
import json, sys, os
path, theme = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
    if not isinstance(data, dict): data = {}
except Exception:
    data = {}
data["wc3Sounds.theme"] = theme
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(data, open(path, "w"), indent=2)
PYEOF
        fi
    else
        echo "  VS Code extension .vsix not available yet (will be on the GitHub release)."
    fi
else
    echo "  VS Code ('code' CLI) not found; skipping. Install the .vsix manually if you use VS Code."
fi

# Save state
echo "$VERSION" > "$CONFIG_DIR/version"
echo "$THEME"   > "$CONFIG_DIR/theme"

# Platform desktop integration for Cursor wrapper
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
    WRAPPER_APP="$HOME/Applications/Cursor with Sound.app"
    mkdir -p "$WRAPPER_APP/Contents/MacOS" "$WRAPPER_APP/Contents/Resources"
    for app_path in "/Applications/Cursor.app" "$HOME/Applications/Cursor.app"; do
        if [ -f "$app_path/Contents/Resources/Cursor.icns" ]; then
            cp "$app_path/Contents/Resources/Cursor.icns" "$WRAPPER_APP/Contents/Resources/AppIcon.icns"
            break
        fi
    done
    cat > "$WRAPPER_APP/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>launcher</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>com.wc3-sounds.wrapper</string>
    <key>CFBundleName</key><string>Cursor with Sound</string>
    <key>CFBundleDisplayName</key><string>Cursor with Sound</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>10.13</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
    cat > "$WRAPPER_APP/Contents/MacOS/launcher" << EOF
#!/bin/bash
SOUNDS_DIR="$SOUNDS_DIR"
afplay "\$SOUNDS_DIR/startup.wav" 2>/dev/null &
CURSOR_BIN=""
for path in "/Applications/Cursor.app/Contents/MacOS/Cursor" "\$HOME/Applications/Cursor.app/Contents/MacOS/Cursor"; do
    [ -x "\$path" ] && { CURSOR_BIN="\$path"; break; }
done
[ -z "\$CURSOR_BIN" ] && { osascript -e 'display dialog "Cursor not found." buttons {"OK"} default button "OK" with icon stop'; exit 1; }
"\$CURSOR_BIN" "\$@"
afplay "\$SOUNDS_DIR/shutdown.wav" 2>/dev/null
EOF
    chmod +x "$WRAPPER_APP/Contents/MacOS/launcher"
    touch "$WRAPPER_APP"
fi

echo ""
echo "Done! Theme '$THEME' configured for:"
echo "  - Cursor      : startup, shutdown (wrapper) + send (hook)"
echo "  - Claude Code : startup, send, shutdown (hooks)"
echo "  - VS Code     : startup, shutdown (extension, if 'code' present)"
echo ""
echo "Restart your editors to activate hooks."
echo "Commands:"
echo "  Switch theme: curl -fsSL $REPO_URL/install.sh | bash -s -- --theme orc"
echo "  Uninstall:    curl -fsSL $REPO_URL/install.sh | bash -s -- --uninstall"
