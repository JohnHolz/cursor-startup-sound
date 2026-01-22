# Cursor Startup Sound 🔊

Play sounds when using [Cursor](https://cursor.com) editor:
- **Startup sound** - when opening Cursor
- **Shutdown sound** - when closing Cursor
- **Send sound** - when sending a message to AI

## Install

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex
```

> **Note:** Restart Cursor after installation to activate the send sound hook.

## Update

Run the same install command again - it will automatically update to the latest version.

## Uninstall

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash -s -- --uninstall
```

### Windows (PowerShell)

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1))) --uninstall
```

## How it works

- **Startup/Shutdown**: Uses a wrapper script that plays sounds before/after launching Cursor
- **Send sound**: Uses [Cursor Hooks](https://cursor.com/docs/agent/hooks) (`beforeSubmitPrompt` event)

## License

MIT
