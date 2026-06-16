// WC3 Sounds — VS Code / Cursor extension
// Plays Warcraft-3-style voices on startup, shutdown, and (optionally) AI send.
//
// Design notes:
// - Audio is produced by spawning the OS player (afplay / paplay|aplay / powershell),
//   the same approach used by the CLI installers. No webview: a webview cannot be
//   created during shutdown, which is exactly when we need the shutdown sound.
// - Shutdown plays from deactivate() using a DETACHED + unref()'d child so the player
//   survives the dying extension host process.

const vscode = require('vscode');
const cp = require('child_process');
const os = require('os');

/** @type {vscode.ExtensionContext} */
let extCtx;

function cfg() {
  return vscode.workspace.getConfiguration('wc3Sounds');
}

/** Absolute path to a bundled sound: sounds/<theme>/<name>.wav */
function soundPath(theme, name) {
  return vscode.Uri.joinPath(extCtx.extensionUri, 'sounds', theme, `${name}.wav`).fsPath;
}

/**
 * Play a wav file by spawning the platform's audio player.
 * @param {string} file absolute path to a .wav
 * @param {{detached?: boolean}} opts
 */
function playSound(file, opts = {}) {
  const detached = !!opts.detached;
  const platform = os.platform();

  /** @type {Array<{cmd: string, args: string[]}>} */
  let candidates;
  if (platform === 'darwin') {
    candidates = [{ cmd: 'afplay', args: [file] }];
  } else if (platform === 'win32') {
    const ps = `(New-Object Media.SoundPlayer '${file.replace(/'/g, "''")}').PlaySync()`;
    candidates = [
      { cmd: 'powershell', args: ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', ps] }
    ];
  } else {
    // Linux: prefer PulseAudio/PipeWire (paplay), fall back to ALSA (aplay).
    candidates = [
      { cmd: 'paplay', args: [file] },
      { cmd: 'aplay', args: [file] }
    ];
  }

  const trySpawn = (i) => {
    if (i >= candidates.length) return;
    const { cmd, args } = candidates[i];
    let child;
    try {
      child = cp.spawn(cmd, args, { detached, stdio: 'ignore', windowsHide: true });
    } catch (_) {
      trySpawn(i + 1);
      return;
    }
    child.on('error', () => trySpawn(i + 1)); // e.g. paplay not installed -> try aplay
    if (detached && child.unref) child.unref();
  };

  trySpawn(0);
}

function activate(context) {
  extCtx = context;

  const c = cfg();
  if (c.get('enableStartup')) {
    playSound(soundPath(c.get('theme'), 'startup'));
  }

  context.subscriptions.push(
    vscode.commands.registerCommand('wc3Sounds.playSend', () => {
      if (cfg().get('enableSend')) {
        playSound(soundPath(cfg().get('theme'), 'send'));
      }
    }),
    vscode.commands.registerCommand('wc3Sounds.playStartup', () => {
      playSound(soundPath(cfg().get('theme'), 'startup'));
    }),
    vscode.commands.registerCommand('wc3Sounds.playShutdown', () => {
      playSound(soundPath(cfg().get('theme'), 'shutdown'));
    })
  );
}

function deactivate() {
  // Runs as the host tears down. Keep it synchronous and spawn detached so the
  // player outlives this process. Clip is short (<1s) so it finishes quickly.
  if (!extCtx) return;
  const c = cfg();
  if (c.get('enableShutdown')) {
    playSound(soundPath(c.get('theme'), 'shutdown'), { detached: true });
  }
}

module.exports = { activate, deactivate };
