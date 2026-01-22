# Cursor Startup Sound 🔊

Play a startup sound every time you open [Cursor](https://cursor.com) editor.

## Install

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.sh | bash
```

### Windows

```powershell
irm https://raw.githubusercontent.com/JohnHolz/cursor-startup-sound/main/install.ps1 | iex
```

## Uninstall

<details>
<summary>Linux</summary>

```bash
rm -f ~/.local/share/sounds/cursor-startup.wav ~/.local/bin/cursor-with-sound ~/.local/share/applications/cursor.desktop
```
</details>

<details>
<summary>macOS</summary>

```bash
rm -f ~/Library/Sounds/cursor-startup.wav ~/.local/bin/cursor-with-sound
```
</details>

<details>
<summary>Windows</summary>

```powershell
Remove-Item -Recurse "$env:LOCALAPPDATA\CursorStartupSound"; Remove-Item "$env:USERPROFILE\Desktop\Cursor (with sound).lnk"
```
</details>

## License

MIT
