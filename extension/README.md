# WC3 Sounds 🔊

Warcraft-3-style **Peasant/Peon** voices in your editor:

- **Startup** — when the editor opens (*"Ready to work!"*)
- **Shutdown** — when the window closes (*"Job's done" / "Work complete!"*)
- **Send** *(optional)* — bound to a keybinding (see note below)

Works in **VS Code** and **Cursor**.

## Themes

Pick in settings → `wc3Sounds.theme`:

| Theme | Voice |
|-------|-------|
| `human` | Peasant |
| `orc`   | Peon |

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `wc3Sounds.theme` | `human` | `human` or `orc` |
| `wc3Sounds.enableStartup` | `true` | Play on startup |
| `wc3Sounds.enableShutdown` | `true` | Play on window close |
| `wc3Sounds.enableSend` | `false` | Play on the send keybinding (VS Code) |

## About the "send" sound

There is **no public VS Code API** to detect "user sent a message to the AI chat".
This extension ships an optional command (`wc3Sounds.playSend`) bound to `Ctrl+Enter`
when `wc3Sounds.enableSend` is on and a chat input is focused — best-effort.

For a **reliable** send sound, use the CLI installer from the repo, which wires it via
**Cursor hooks** (`beforeSubmitPrompt`) and **Claude Code hooks** (`UserPromptSubmit`).

## Install (from VSIX)

This extension is distributed via GitHub Releases (no marketplace).

1. Download `wc3-sounds-<version>.vsix` from the release.
2. **VS Code:** Extensions view → `…` menu → *Install from VSIX…* — or `code --install-extension wc3-sounds-<version>.vsix`
3. **Cursor:** Extensions view → `…` menu → *Install from VSIX…* — or `cursor --install-extension wc3-sounds-<version>.vsix`
4. Reload the window. Startup sound plays on next launch.

## Audio

Requires a system audio player (already present on virtually all desktops):
`afplay` (macOS), `paplay`/`aplay` (Linux), `powershell Media.SoundPlayer` (Windows).

## License

MIT (extension code). Sound clips are Warcraft III assets © Blizzard Entertainment —
provided for personal use.
