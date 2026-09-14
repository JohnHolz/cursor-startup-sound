# WC3 Editor Sounds 🔊

Warcraft-3-style voices in your editor — on **startup**, **shutdown**, and when you **send a message to the AI**.

Pick your faction:

| Theme | Voice | Startup | Send | Shutdown |
|-------|-------|---------|------|----------|
| `human` | Peasant | *"Ready to work!"* | *"Yes?"* | *"Job's done"* |
| `orc`   | Peon    | *"Ready to work!"* | *"What you want?"* | *"Work complete!"* |

**Bonus:** a **Barony gnome** squeaks — one of 8 random clips — every time the agent finishes a step, edits its
own instructions (memory, plans, `CLAUDE.md`, `AGENTS.md`, Cursor rules), or compacts context. Works in
**Claude Code**, **Cursor** and **VS Code** (Copilot agent hooks). Opt out with `--no-gnome`.

Works in **Cursor**, **VS Code**, and **Claude Code** — installable via **CLI** or as a **VS Code extension**.

---

## What works where

| Environment | Startup | Shutdown | Send | Gnome | How it's delivered |
|-------------|:-------:|:--------:|:----:|:-----:|--------------------|
| **Cursor**      | ✅ | ✅ | ✅ | ✅ | wrapper script + `~/.cursor/hooks.json` (`beforeSubmitPrompt`, plus `afterAgentResponse` / `afterFileEdit` / `preCompact` for the gnome) |
| **VS Code**     | ✅ | ✅ | ✅* | ✅* | extension (`onStartupFinished` / `deactivate`) + `~/.copilot/hooks/wc3-sounds.json` (Copilot agent hooks: `UserPromptSubmit` / `Stop` / `PostToolUse` / `PreCompact`)* |
| **Claude Code** | ✅ | ✅ | ✅ | ✅ | `~/.claude/settings.json` hooks (`SessionStart` / `Stop` / `UserPromptSubmit`, plus `MessageDisplay` / `PostToolUse` / `PreCompact` for the gnome) |

\* VS Code: send, *"Job's done"* after each answer, and the gnome ride on **Copilot agent hooks** (Preview,
`chat.useHooks`, on by default) — they play in Copilot's agent mode, not in other chat extensions. VS Code has no
per-message hook, so the gnome there squeaks on every tool call instead. The extension's optional send
keybinding (off by default) stays as a fallback for other chats. If you have turned on `chat.useClaudeHooks`,
VS Code also runs the Claude Code hooks from `~/.claude/settings.json` and every voice would play twice; in that
case delete `~/.copilot/hooks/wc3-sounds.json` and let the Claude Code hooks do the work.

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

The uninstaller removes our hooks from `~/.claude/settings.json` and `~/.cursor/hooks.json` **without touching
your other hooks** (via `python3`/`jq` on Unix, native JSON on Windows) and deletes `~/.copilot/hooks/wc3-sounds.json`.

---

## How it works

- **Startup / Shutdown** — CLI: a wrapper that plays sounds before/after launching Cursor. Extension:
  plays in `activate()` (`onStartupFinished`) and `deactivate()` (detached so it outlives the window).
- **Send** — Cursor: [`beforeSubmitPrompt` hook](https://cursor.com/docs/agent/hooks). Claude Code:
  `UserPromptSubmit` hook. VS Code: `UserPromptSubmit` via
  [Copilot agent hooks](https://code.visualstudio.com/docs/copilot/customization/hooks), read from
  `~/.copilot/hooks/*.json` (we write our own file there, so nothing of yours is merged or changed); the
  optional keybinding remains for other chats.
- **Gnome** — one hook script (`gnome.sh` / `gnome.bat`) shared by all three editors; it looks at
  `hook_event_name` to know who called:
  - *Claude Code*: `MessageDisplay` (fires per batch of streamed lines; only the `final` flush counts, so one
    clip per assistant message), `PostToolUse` for `Write|Edit|MultiEdit` (only when the file is under
    `~/.claude/projects/*/memory/`, `~/.claude/plans/`, or is a `CLAUDE.md`), and `PreCompact`.
  - *Cursor*: `afterAgentResponse` (one clip per assistant message), `afterFileEdit` (only `.cursor/rules/`,
    `.cursor/plans/`, `.cursorrules`, `AGENTS.md`, `CLAUDE.md`), and `preCompact`.
  - *VS Code*: `PostToolUse` on every tool call (there is no per-message event, and VS Code ignores hook
    matchers) and `PreCompact`.

  It picks one of 8 clips at random (the gnome's idle and "spotted you" voices; its death screams are left
  out); a 3 s cooldown, longer than the longest clip, keeps two clips from ever overlapping. The script answers
  `{}` on stdout (every editor parses hook output as JSON) except on `MessageDisplay`, where stdout would
  replace the text on screen.
- **Only one voice at a time** — WC3 voices outrank the gnome: a WC3 hook (Claude Code or Cursor) stops a gnome
  that is playing or waiting, and the gnome waits for a WC3 voice to finish before squeaking (Linux/macOS; on
  Windows the hooks can't track playback, so only the cooldown applies).
- **Audio players** — `afplay` (macOS), `paplay`/`aplay` (Linux), `Media.SoundPlayer` (Windows).

## Requirements

A system audio player (present by default on virtually all desktops) and, for the CLI's settings merge
(`~/.claude/settings.json`, `~/.cursor/hooks.json`), `python3` or `jq` on Linux/macOS (falls back to printing
manual steps if neither is present).

## Development

```bash
bash tests/test-install.sh        # installs into a throwaway $HOME with fake players, feeds every editor's hook JSON
bash tests/test-install.sh --jq   # same, with python3 hidden so the jq merge path is exercised
```

## License

Code: MIT. Sound clips are Warcraft III assets © Blizzard Entertainment and Barony assets © Turning Wheel LLC,
included for personal use.
