# WC3 Editor Sounds - Windows installer
# Plays Warcraft-3-style sounds in Cursor, VS Code and Claude Code.
# Run:       irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex
# Theme/uninstall: & ([scriptblock]::Create((irm .../install.ps1))) --theme orc

param()

$ErrorActionPreference = "Stop"

$VERSION  = "2.0.0"
$REPO_URL = "https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
$THEME = $env:WC3_THEME
$DO_UNINSTALL = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--uninstall" { $DO_UNINSTALL = $true }
        "-u"          { $DO_UNINSTALL = $true }
        "--theme"     { $THEME = $args[$i + 1]; $i++ }
        default {
            if ($args[$i] -like "--theme=*") { $THEME = $args[$i].Split("=")[1] }
        }
    }
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$CONFIG_DIR        = "$env:LOCALAPPDATA\wc3-sounds"
$SOUNDS_DIR        = "$CONFIG_DIR\sounds"
$CLAUDE_HOOK_DIR   = "$CONFIG_DIR\claude-hooks"
$CONFIG_FILE       = "$CONFIG_DIR\version.txt"
$THEME_FILE        = "$CONFIG_DIR\theme.txt"
$CURSOR_HOOKS_DIR  = "$env:USERPROFILE\.cursor\hooks"
$CURSOR_HOOKS_FILE = "$env:USERPROFILE\.cursor\hooks.json"
$CLAUDE_SETTINGS   = "$env:USERPROFILE\.claude\settings.json"
$CURSOR_PATH       = "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe"
if (-not (Test-Path $CURSOR_PATH)) { $CURSOR_PATH = "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe" }

# ---------------------------------------------------------------------------
# Claude settings.json merge — preserves existing user hooks
# ---------------------------------------------------------------------------
function Merge-ClaudeHooks {
    param([string]$Mode, [hashtable]$Map)
    if (Test-Path $CLAUDE_SETTINGS) {
        try { $json = Get-Content $CLAUDE_SETTINGS -Raw | ConvertFrom-Json -ErrorAction Stop }
        catch { return $false }
    } else { $json = [PSCustomObject]@{} }
    if (-not ($json.PSObject.Properties.Name -contains 'hooks') -or $null -eq $json.hooks) {
        $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    foreach ($event in $Map.Keys) {
        $cmd = $Map[$event]
        $existing = @()
        if (($json.hooks.PSObject.Properties.Name -contains $event) -and $json.hooks.$event) {
            $existing = @($json.hooks.$event | Where-Object {
                $ours = $false
                foreach ($h in @($_.hooks)) { if ($h.command -eq $cmd) { $ours = $true } }
                -not $ours
            })
        }
        if ($Mode -eq 'add') {
            $entry = [PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = 'command'; command = $cmd }) }
            $existing = @($existing) + $entry
        }
        if ($existing.Count -gt 0) {
            $json.hooks | Add-Member -NotePropertyName $event -NotePropertyValue $existing -Force
        } elseif ($json.hooks.PSObject.Properties.Name -contains $event) {
            $json.hooks.PSObject.Properties.Remove($event)
        }
    }
    if ($json.hooks.PSObject.Properties.Count -eq 0) { $json.PSObject.Properties.Remove('hooks') }
    $dir = Split-Path $CLAUDE_SETTINGS -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    ($json | ConvertTo-Json -Depth 20) | Set-Content -Path $CLAUDE_SETTINGS -Encoding UTF8
    return $true
}

$claudeMap = @{
    "SessionStart"     = "$CLAUDE_HOOK_DIR\startup.bat"
    "UserPromptSubmit" = "$CLAUDE_HOOK_DIR\send.bat"
    "Stop"             = "$CLAUDE_HOOK_DIR\shutdown.bat"
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if ($DO_UNINSTALL) {
    Write-Host "Uninstalling WC3 Editor Sounds..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $CONFIG_DIR -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:LOCALAPPDATA\CursorStartupSound" -ErrorAction SilentlyContinue  # legacy v1
    Remove-Item -Force "$CURSOR_HOOKS_DIR\play-send-sound.ps1" -ErrorAction SilentlyContinue
    Remove-Item -Force "$CURSOR_HOOKS_DIR\play-send-sound.bat" -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\Cursor (with sound).lnk" -ErrorAction SilentlyContinue
    if (Test-Path $CLAUDE_SETTINGS) {
        if (Merge-ClaudeHooks -Mode 'remove' -Map $claudeMap) {
            Write-Host "  Removed Claude Code hooks from settings.json"
        } else {
            Write-Host "  Note: edit ~/.claude/settings.json to remove the wc3-sounds hooks" -ForegroundColor Yellow
        }
    }
    if (Get-Command code -ErrorAction SilentlyContinue) {
        & code --uninstall-extension johnholz.wc3-sounds 2>$null | Out-Null
    }
    Write-Host "  Note: you may want to edit ~/.cursor/hooks.json to remove the beforeSubmitPrompt hook"
    Write-Host "Done!" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Theme resolution
# ---------------------------------------------------------------------------
if (-not $THEME) {
    Write-Host "Choose a sound theme:"
    Write-Host "  1) human (Peasant)"
    Write-Host "  2) orc   (Peon)"
    $choice = Read-Host "Theme [1]"
    if ($choice -eq "2" -or $choice -eq "orc") { $THEME = "orc" } else { $THEME = "human" }
}
if ($THEME -ne "human" -and $THEME -ne "orc") {
    Write-Host "Invalid theme '$THEME' (use human or orc)" -ForegroundColor Red; exit 1
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
$ACTION = "Installing"
if (Test-Path $CONFIG_FILE) { $ACTION = "Updating ($(Get-Content $CONFIG_FILE) -> $VERSION)" }

Write-Host "=== WC3 Editor Sounds v$VERSION ===" -ForegroundColor Cyan
Write-Host "$ACTION for Windows, theme: $THEME"
Write-Host ""

New-Item -ItemType Directory -Force -Path $SOUNDS_DIR, $CLAUDE_HOOK_DIR, $CURSOR_HOOKS_DIR | Out-Null

# --- 1. Sounds -------------------------------------------------------------
Write-Host "[1/5] Downloading $THEME sounds..."
foreach ($name in @("startup", "send", "shutdown")) {
    Invoke-WebRequest -Uri "$REPO_URL/sounds/$THEME/$name.wav" -OutFile "$SOUNDS_DIR\$name.wav"
}

# --- 2. Cursor wrapper -----------------------------------------------------
Write-Host "[2/5] Configuring Cursor wrapper..."
$wrapperPath = "$CONFIG_DIR\cursor-with-sound.bat"
@"
@echo off
start /b powershell -NoProfile -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\startup.wav').PlaySync()"
"$CURSOR_PATH" %*
powershell -NoProfile -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer '$SOUNDS_DIR\shutdown.wav').PlaySync()"
"@ | Set-Content -Path $wrapperPath -Encoding ASCII

# --- 3. Cursor send hook ---------------------------------------------------
Write-Host "[3/5] Configuring Cursor send hook..."
$hookPs1 = "$CURSOR_HOOKS_DIR\play-send-sound.ps1"
@"
`$null = `$input | Out-Null  # drain stdin (required by Cursor)
(New-Object Media.SoundPlayer "$SOUNDS_DIR\send.wav").Play()
Write-Output '{"continue": true}'
"@ | Set-Content -Path $hookPs1 -Encoding UTF8
$hookBat = "$CURSOR_HOOKS_DIR\play-send-sound.bat"
@"
@echo off
powershell -NoProfile -WindowStyle Hidden -File "$hookPs1"
"@ | Set-Content -Path $hookBat -Encoding ASCII

if (-not (Test-Path $CURSOR_HOOKS_FILE)) {
    @"
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [
      { "command": "$($hookBat -replace '\\','\\')" }
    ]
  }
}
"@ | Set-Content -Path $CURSOR_HOOKS_FILE -Encoding UTF8
} elseif (-not (Select-String -Path $CURSOR_HOOKS_FILE -Pattern "play-send-sound" -Quiet)) {
    Write-Host "  Note: ~/.cursor/hooks.json exists. Add a beforeSubmitPrompt hook pointing to:" -ForegroundColor Yellow
    Write-Host "    $hookBat"
}

# --- 4. Claude Code hooks --------------------------------------------------
Write-Host "[4/5] Configuring Claude Code hooks..."
foreach ($evt in @("startup", "send", "shutdown")) {
    $ps1 = "$CLAUDE_HOOK_DIR\$evt.ps1"
    @"
`$null = `$input | Out-Null  # drain stdin
(New-Object Media.SoundPlayer "$SOUNDS_DIR\$evt.wav").Play()
"@ | Set-Content -Path $ps1 -Encoding UTF8
    @"
@echo off
powershell -NoProfile -WindowStyle Hidden -File "$ps1"
"@ | Set-Content -Path "$CLAUDE_HOOK_DIR\$evt.bat" -Encoding ASCII
}
if (Merge-ClaudeHooks -Mode 'add' -Map $claudeMap) {
    Write-Host "  Claude Code hooks installed (SessionStart / UserPromptSubmit / Stop)"
} else {
    Write-Host "  Note: settings.json unparseable; add the wc3-sounds .bat hooks manually." -ForegroundColor Yellow
}

# --- 5. VS Code extension --------------------------------------------------
Write-Host "[5/5] Configuring VS Code..."
if (Get-Command code -ErrorAction SilentlyContinue) {
    $vsix = "$env:TEMP\wc3-sounds-$VERSION.vsix"
    try {
        Invoke-WebRequest -Uri "$REPO_URL/extension/wc3-sounds-$VERSION.vsix" -OutFile $vsix -ErrorAction Stop
        & code --install-extension $vsix --force 2>$null | Out-Null
        Write-Host "  VS Code extension installed."
        # best-effort: set theme in VS Code user settings
        $vscodeSettings = "$env:APPDATA\Code\User\settings.json"
        if (Test-Path (Split-Path $vscodeSettings -Parent)) {
            try {
                if (Test-Path $vscodeSettings) { $s = Get-Content $vscodeSettings -Raw | ConvertFrom-Json } else { $s = [PSCustomObject]@{} }
                $s | Add-Member -NotePropertyName "wc3Sounds.theme" -NotePropertyValue $THEME -Force
                ($s | ConvertTo-Json -Depth 20) | Set-Content -Path $vscodeSettings -Encoding UTF8
            } catch { }
        }
    } catch {
        Write-Host "  VS Code extension .vsix not available yet (will be on the GitHub release)."
    }
} else {
    Write-Host "  VS Code ('code' CLI) not found; skipping. Install the .vsix manually if you use VS Code."
}

# Save state
Set-Content -Path $CONFIG_FILE -Value $VERSION
Set-Content -Path $THEME_FILE  -Value $THEME

# Desktop shortcut for Cursor wrapper
if (Test-Path $CURSOR_PATH) {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Cursor (with sound).lnk")
    $Shortcut.TargetPath = $wrapperPath
    $Shortcut.IconLocation = $CURSOR_PATH
    $Shortcut.Save()
}

Write-Host ""
Write-Host "Done! Theme '$THEME' configured for:" -ForegroundColor Green
Write-Host "  - Cursor      : startup, shutdown (wrapper) + send (hook)"
Write-Host "  - Claude Code : startup, send, shutdown (hooks)"
Write-Host "  - VS Code     : startup, shutdown (extension, if 'code' present)"
Write-Host ""
Write-Host "Restart your editors to activate hooks."
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  Switch theme: & ([scriptblock]::Create((irm $REPO_URL/install.ps1))) --theme orc"
Write-Host "  Uninstall:    & ([scriptblock]::Create((irm $REPO_URL/install.ps1))) --uninstall"
