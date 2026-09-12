# WC3 Editor Sounds 🔊

Warcraft-3-style voices in your editor — on **startup**, **shutdown**, and when you **send a message to the AI**.

Pick your faction:

| Theme | Voice | Startup | Send | Shutdown |
|-------|-------|---------|------|----------|
| `human` | Peasant | *"Ready to work!"* | *"Yes?"* | *"Job's done"* |
| `orc`   | Peon    | *"Ready to work!"* | *"What you want?"* | *"Work complete!"* |

**Bonus (Claude Code only):** a **Barony gnome** squeaks — one of 12 random clips — every time Claude finishes a
step (each block of progress text), saves a memory, writes a plan, edits `CLAUDE.md`, or compacts context.
Opt out with `--no-gnome`.

Works in **Cursor**, **VS Code**, and **Claude Code** — installable via **CLI** or as a **VS Code extension**.

---

## What works where

| Environment | Startup | Shutdown | Send | Gnome | How it's delivered |
|-------------|:-------:|:--------:|:----:|:-----:|--------------------|
| **Cursor**      | ✅ | ✅ | ✅ | ➖ | wrapper script + `beforeSubmitPrompt` hook |
| **VS Code**     | ✅ | ✅ | ⚠️ | ➖ | extension (`onStartupFinished` / `deactivate`); send only via optional keybinding* |
| **Claude Code** | ✅ | ✅ | ✅ | ✅ | `~/.claude/settings.json` hooks (`SessionStart` / `Stop` / `UserPromptSubmit`, plus `MessageDisplay` / `PostToolUse` / `PreCompact` for the gnome) |

\* VS Code has **no public API** to detect "message sent to the AI", so the send sound there is a best-effort
keybinding (off by default). On Cursor and Claude Code the send sound is hook-driven and reliable.

---

## Install — CLI (Cursor + VS Code + Claude Code)

Configures all three at once and lets you pick a theme.

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash
# non-interactive theme:
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash -s -- --theme orc
# without the gnome:
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash -s -- --no-gnome
```

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex
# with a theme:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1))) --theme orc
# without the gnome:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1))) --no-gnome
```

> Restart your editors after installing so the hooks load. Run again any time to switch theme or update.

---

## Install — Extension (VS Code / Cursor only)

Prefer the GUI? Grab the `.vsix` from the [latest Release](https://github.com/JohnHolz/cursor-startup-sound/releases):

- **VS Code:** Extensions → `…` → *Install from VSIX…* — or `code --install-extension wc3-sounds-2.0.0.vsix`
- **Cursor:** Extensions → `…` → *Install from VSIX…* — or `cursor --install-extension wc3-sounds-2.0.0.vsix`

Then choose your theme in Settings → search `wc3Sounds`:
`wc3Sounds.theme`, `wc3Sounds.enableStartup`, `wc3Sounds.enableShutdown`, `wc3Sounds.enableSend`.

---

## Uninstall

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash -s -- --uninstall
```
### Windows
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1))) --uninstall
```

The uninstaller removes our hooks from `~/.claude/settings.json` **without touching your other hooks**
(via `python3`/`jq` on Unix, native JSON on Windows).

---

## How it works

- **Startup / Shutdown** — CLI: a wrapper that plays sounds before/after launching Cursor. Extension:
  plays in `activate()` (`onStartupFinished`) and `deactivate()` (detached so it outlives the window).
- **Send** — Cursor: [`beforeSubmitPrompt` hook](https://cursor.com/docs/agent/hooks). Claude Code:
  `UserPromptSubmit` hook. VS Code: optional keybinding.
- **Gnome** — Claude Code only. One hook script (`gnome.sh` / `gnome.bat`) registered on `MessageDisplay`
  (fires per batch of streamed lines; the script only reacts to the `final` flush, so one clip per assistant
  message), `PostToolUse` for `Write|Edit|MultiEdit` (only when the file is under
  `~/.claude/projects/*/memory/`, `~/.claude/plans/`, or is a `CLAUDE.md`), and `PreCompact`. It picks one of
  12 clips at random; a 2 s debounce keeps clips from piling up.
- **Audio players** — `afplay` (macOS), `paplay`/`aplay` (Linux), `Media.SoundPlayer` (Windows).

## Requirements

A system audio player (present by default on virtually all desktops) and, for the CLI's settings merge,
`python3` or `jq` on Linux/macOS (falls back to printing manual steps if neither is present).

## License

Code: MIT. Sound clips are Warcraft III assets © Blizzard Entertainment and Barony assets © Turning Wheel LLC,
included for personal use.
