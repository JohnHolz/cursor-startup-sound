# Cursor Startup Sound 🔊

Play startup and shutdown sounds when opening and closing [Cursor](https://cursor.com) editor.

## Install

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex
```

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

## License

MIT
