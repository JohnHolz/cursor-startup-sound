#!/bin/bash
# Hermetic test for install.sh: installs into a throwaway $HOME from the local checkout
# (WC3_REPO_URL=file://...), with fake audio players that log what they were asked to play,
# then feeds each editor's real hook JSON into the generated scripts.
#
#   bash tests/test-install.sh
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T"   # so a leaked mktemp file from the installer shows up here

export HOME="$T/home"
export WC3_REPO_URL="file://$REPO"
export WC3_TEST_LOG="$T/played.log"
mkdir -p "$HOME" "$T/bin"

# Fake players / editor CLIs, first in PATH
for p in paplay aplay afplay; do
    printf '#!/bin/bash\necho "$1" >> "$WC3_TEST_LOG"\n' > "$T/bin/$p"; chmod +x "$T/bin/$p"
done
printf '#!/bin/bash\nexit 0\n' > "$T/bin/code"; chmod +x "$T/bin/code"
export PATH="$T/bin:$PATH"

# --jq: hide python3 so the installer takes the jq merge path
if [ "${1:-}" = "--jq" ]; then
    mkdir -p "$T/sysbin"
    for d in /usr/local/bin /usr/bin /bin; do
        for f in "$d"/*; do
            n="$(basename "$f")"
            case "$n" in python|python3*) continue ;; esac
            [ -e "$T/sysbin/$n" ] || ln -s "$f" "$T/sysbin/$n"
        done
    done
    export PATH="$T/bin:$T/sysbin"
    command -v python3 >/dev/null && { echo "python3 still visible; --jq mode broken"; exit 1; }
    echo "(jq merge path: python3 hidden)"
fi

PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL - $1"; [ -n "${2:-}" ] && echo "         $2"; }
check() { # check <desc> <cmd...>
    local d="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi
}

CURSOR_HOOKS="$HOME/.cursor/hooks.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CONFIG_DIR="$HOME/.config/wc3-sounds"

# Pre-existing user config that the installer must preserve
mkdir -p "$HOME/.cursor" "$HOME/.claude"
cat > "$CURSOR_HOOKS" <<'EOF'
{ "version": 1, "hooks": { "beforeShellExecution": [ { "command": "/usr/local/bin/audit.sh" } ] } }
EOF
cat > "$CLAUDE_SETTINGS" <<'EOF'
{ "model": "opus", "hooks": { "Notification": [ { "hooks": [ { "type": "command", "command": "/usr/local/bin/notify.sh" } ] } ] } }
EOF

echo "== install (twice, must be idempotent)"
bash "$REPO/install.sh" --theme human </dev/null >"$T/install1.log" 2>&1 || { fail "install.sh exit 0" "$(tail -5 "$T/install1.log")"; }
bash "$REPO/install.sh" --theme human </dev/null >"$T/install2.log" 2>&1 || { fail "install.sh re-run exit 0" "$(tail -5 "$T/install2.log")"; }

echo "== Cursor hooks.json"
jqh() { jq -r "$1" "$CURSOR_HOOKS"; }
check "keeps the user's own hook"        test "$(jqh '.hooks.beforeShellExecution[0].command')" = "/usr/local/bin/audit.sh"
check "keeps version: 1"                 test "$(jqh '.version')" = "1"
check "beforeSubmitPrompt -> send hook"  test "$(jqh '.hooks.beforeSubmitPrompt | length')" = "1"
check "beforeSubmitPrompt not duplicated on re-run" test "$(jqh '[.hooks.beforeSubmitPrompt[].command] | map(select(endswith("play-send-sound.sh"))) | length')" = "1"
for evt in afterAgentResponse afterFileEdit preCompact; do
    check "$evt -> exactly one gnome hook" test "$(jqh "[.hooks.$evt[].command] | map(select(endswith(\"gnome.sh\"))) | length")" = "1"
done
GNOME_SH="$(jqh '.hooks.afterAgentResponse[0].command')"
SEND_SH="$(jqh '.hooks.beforeSubmitPrompt[0].command')"
check "gnome hook script exists and is executable" test -x "$GNOME_SH"

echo "== Claude Code settings.json (unchanged behaviour)"
jqc() { jq -r "$1" "$CLAUDE_SETTINGS"; }
check "keeps the user's own settings" test "$(jqc '.model')" = "opus"
check "keeps the user's own hook"     test "$(jqc '.hooks.Notification[0].hooks[0].command')" = "/usr/local/bin/notify.sh"
for evt in MessageDisplay PostToolUse PreCompact; do
    check "$evt -> exactly one gnome hook" test "$(jqc "[.hooks.$evt[].hooks[].command] | map(select(endswith(\"gnome.sh\"))) | length")" = "1"
done
check "same gnome script shared by Cursor and Claude Code" test "$(jqc '.hooks.PreCompact[0].hooks[0].command')" = "$GNOME_SH"

echo "== VS Code: ~/.copilot/hooks/wc3-sounds.json (Copilot agent hooks read this dir by default)"
COPILOT_HOOKS="$HOME/.copilot/hooks/wc3-sounds.json"
jqv() { jq -r "$1" "$COPILOT_HOOKS" 2>/dev/null; }
check "hook file exists and is valid JSON"  jq -e . "$COPILOT_HOOKS"
check "UserPromptSubmit -> send hook"       test "$(jqv '.hooks.UserPromptSubmit[0].command')" = "$(jqc '.hooks.UserPromptSubmit[0].hooks[0].command')"
check "Stop -> shutdown hook"               test "$(jqv '.hooks.Stop[0].command')" = "$(jqc '.hooks.Stop[0].hooks[0].command')"
check "PostToolUse -> gnome (every tool)"   test "$(jqv '.hooks.PostToolUse[0].command')" = "$GNOME_SH"
check "PreCompact -> gnome"                 test "$(jqv '.hooks.PreCompact[0].command')" = "$GNOME_SH"
check "entries are type: command"           test "$(jqv '[.hooks[][] | .type] | unique | join(",")')" = "command"
check "no SessionStart (the extension already plays startup; it would overlap the send voice)" test "$(jqv '.hooks.SessionStart // "none"')" = "none"

# --- gnome.sh behaviour ------------------------------------------------------
# run_gnome <json>: fresh cooldown + log, run the hook, wait for the (async) player. Sets $OUT (stdout) and $PLAYED.
run_gnome() {
    rm -f "$CONFIG_DIR/gnome.stamp" "$CONFIG_DIR/gnome.pid" "$CONFIG_DIR/wc3.pid" "$WC3_TEST_LOG"
    OUT="$(printf '%s' "$1" | bash "$GNOME_SH")"
    local i=0
    while [ $i -lt 20 ] && [ ! -s "$WC3_TEST_LOG" ]; do sleep 0.1; i=$((i + 1)); done
    PLAYED="$(cat "$WC3_TEST_LOG" 2>/dev/null || true)"
}
plays()  { run_gnome "$2"; if [[ "$PLAYED" == *"/gnome/gnome"?".wav" ]]; then ok "$1"; else fail "$1" "played: '$PLAYED'"; fi; }
silent() { run_gnome "$2"; if [ -z "$PLAYED" ]; then ok "$1"; else fail "$1" "played: '$PLAYED'"; fi; }

echo "== gnome.sh: Cursor"
plays  "afterAgentResponse plays"                '{"conversation_id":"c","generation_id":"g","hook_event_name":"afterAgentResponse","cursor_version":"3.9.16","workspace_roots":["/w"],"text":"done"}'
check  "afterAgentResponse answers {} on stdout"  test "$OUT" = "{}"
plays  "afterFileEdit on .cursor/rules plays"     '{"hook_event_name":"afterFileEdit","file_path":"/w/.cursor/rules/style.mdc","edits":[{"old_string":"a","new_string":"b"}]}'
plays  "afterFileEdit on .cursor/plans plays"     '{"hook_event_name":"afterFileEdit","file_path":"/w/.cursor/plans/feature.plan.md","edits":[]}'
plays  "afterFileEdit on AGENTS.md plays"         '{"hook_event_name":"afterFileEdit","file_path":"/w/AGENTS.md","edits":[]}'
plays  "afterFileEdit on .cursorrules plays"      '{"hook_event_name":"afterFileEdit","file_path":"/w/.cursorrules","edits":[]}'
silent "afterFileEdit on ordinary source is silent" '{"hook_event_name":"afterFileEdit","file_path":"/w/src/app.js","edits":[]}'
plays  "preCompact plays"                         '{"hook_event_name":"preCompact","trigger":"auto","context_usage_percent":91}'

echo "== gnome.sh: VS Code (Copilot agent hooks from ~/.copilot/hooks/wc3-sounds.json)"
plays  "PostToolUse on any tool plays (no per-message event there)" '{"timestamp":"2026-09-14T13:00:00Z","cwd":"/w","hook_event_name":"PostToolUse","tool_name":"editFiles","tool_input":{"filePath":"/w/src/app.js"},"tool_response":{}}'
check  "PostToolUse answers {} on stdout"          test "$OUT" = "{}"
plays  "PostToolUse on a non-file tool plays"      '{"timestamp":"2026-09-14T13:00:00Z","hook_event_name":"PostToolUse","tool_name":"runInTerminal","tool_input":{"command":"ls"}}'
plays  "PreCompact plays"                          '{"timestamp":"2026-09-14T13:00:00Z","hook_event_name":"PreCompact"}'

echo "== gnome.sh: Claude Code (unchanged)"
silent "PostToolUse on ordinary source is silent"  '{"session_id":"s","transcript_path":"/t","cwd":"/w","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/w/src/app.js"}}'
plays  "PostToolUse on a memory file plays"        '{"session_id":"s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/h/.claude/projects/-w/memory/x.md","content":"y"}}'
plays  "PostToolUse on CLAUDE.md plays"            '{"session_id":"s","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/w/CLAUDE.md"}}'
plays  "MessageDisplay final:true plays"           '{"session_id":"s","hook_event_name":"MessageDisplay","turn_id":"t","message_id":"m","index":3,"final":true,"delta":"hi"}'
check  "MessageDisplay prints NOTHING (stdout would replace the text on screen)" test -z "$OUT"
silent "MessageDisplay final:false is silent"      '{"session_id":"s","hook_event_name":"MessageDisplay","turn_id":"t","message_id":"m","index":0,"final":false,"delta":"hi"}'
plays  "PreCompact plays"                          '{"session_id":"s","hook_event_name":"PreCompact","trigger":"auto"}'

echo "== gnome.sh: only known events play"
silent "unregistered event (Stop) is silent"       '{"session_id":"s","hook_event_name":"Stop","stop_hook_active":false}'
silent "empty stdin is silent"                     ''
silent "garbage stdin is silent"                   '{"foo":"bar"}'
silent "Claude Code MCP tool (name contains Edit) on an ordinary file is silent" '{"session_id":"s","transcript_path":"/t","hook_event_name":"PostToolUse","tool_name":"mcp__notion__EditPage","tool_input":{"file_path":"/w/src/app.js"}}'
plays  "Claude Code MCP tool on a memory file plays" '{"session_id":"s","transcript_path":"/t","hook_event_name":"PostToolUse","tool_name":"mcp__fs__WriteFile","tool_input":{"file_path":"/h/.claude/projects/-w/memory/x.md"}}'

echo "== gnome.sh: pretty-printed JSON (Cursor / VS Code may indent)"
plays  "pretty-printed Cursor afterFileEdit plays"  "$(printf '{\n  "hook_event_name": "afterFileEdit",\n  "file_path": "/w/.cursor/rules/a.mdc",\n  "edits": []\n}')"
plays  "pretty-printed VS Code PostToolUse plays"   "$(printf '{\n  "timestamp": "2026-09-14T13:00:00Z",\n  "hook_event_name": "PostToolUse",\n  "tool_name": "editFiles",\n  "tool_input": {\n    "filePath": "/w/src/app.js"\n  }\n}')"
silent "pretty-printed Claude Code PostToolUse on an ordinary file is silent" "$(printf '{\n  "session_id": "s",\n  "hook_event_name": "PostToolUse",\n  "tool_name": "Edit",\n  "tool_input": {\n    "file_path": "/w/src/app.js"\n  }\n}')"

echo "== gnome.sh: cooldown"
run_gnome '{"hook_event_name":"afterAgentResponse","text":"1"}'
printf '%s' '{"hook_event_name":"afterAgentResponse","text":"2"}' | bash "$GNOME_SH" >/dev/null
sleep 0.5
check "two responses within 3 s -> one clip" test "$(cat "$WC3_TEST_LOG" 2>/dev/null | wc -l)" = "1"

echo "== Cursor send hook: WC3 voice outranks a waiting gnome"
rm -f "$WC3_TEST_LOG" "$CONFIG_DIR/wc3.pid"
# a sleeper in its own process group, like the real gnome (set -m); portable (no setsid on macOS)
FAKE_GNOME=$(bash -c 'set -m; sleep 30 </dev/null >/dev/null 2>&1 & echo $!')
echo "$FAKE_GNOME tok" > "$CONFIG_DIR/gnome.pid"
printf '%s' '{"hook_event_name":"beforeSubmitPrompt","prompt":"hi"}' | bash "$SEND_SH" > "$T/send.out"
sleep 0.3
check "send hook stops the gnome"           bash -c "! kill -0 $FAKE_GNOME 2>/dev/null"
check "send hook records its pid for the gnome to wait on" test -s "$CONFIG_DIR/wc3.pid"
check "send hook still answers continue:true" grep -q '"continue": *true' "$T/send.out"
check "send hook plays send.wav"            grep -q 'send.wav' "$WC3_TEST_LOG"
kill "$FAKE_GNOME" 2>/dev/null

echo "== uninstall"
bash "$REPO/install.sh" --uninstall </dev/null >"$T/uninstall.log" 2>&1 || fail "uninstall exit 0" "$(tail -5 "$T/uninstall.log")"
check "Cursor: user's own hook kept"       test "$(jqh '.hooks.beforeShellExecution[0].command')" = "/usr/local/bin/audit.sh"
check "Cursor: all wc3 hooks removed"      test "$(jqh '[.hooks[][] | .command] | map(select(test("wc3-sounds|play-send-sound|gnome"))) | length')" = "0"
check "Claude: user's own hook kept"       test "$(jqc '.hooks.Notification[0].hooks[0].command')" = "/usr/local/bin/notify.sh"
check "Claude: all wc3 hooks removed"      test "$(jqc '[.hooks[][] | .hooks[].command] | map(select(test("wc3-sounds"))) | length')" = "0"
check "gnome script removed"               test ! -e "$GNOME_SH"
check "VS Code: hook file removed"         test ! -e "$COPILOT_HOOKS"

echo "== --no-gnome keeps the WC3 voices but drops every gnome hook"
bash "$REPO/install.sh" --theme human --no-gnome </dev/null >"$T/install3.log" 2>&1 || fail "install.sh --no-gnome exit 0" "$(tail -5 "$T/install3.log")"
check "Cursor: send hook present"          test "$(jqh '.hooks.beforeSubmitPrompt | length')" = "1"
check "Cursor: no gnome hooks"             test "$(jqh '[.hooks[][] | .command] | map(select(endswith("gnome.sh"))) | length')" = "0"
check "VS Code: send hook present"         test "$(jqv '.hooks.UserPromptSubmit | length')" = "1"
check "VS Code: no gnome hooks"            test "$(jqv '[.hooks[][] | .command] | map(select(endswith("gnome.sh"))) | length')" = "0"
check "Claude: no gnome hooks"             test "$(jqc '[.hooks[][] | .hooks[].command] | map(select(endswith("gnome.sh"))) | length')" = "0"
bash "$REPO/install.sh" --uninstall </dev/null >/dev/null 2>&1

echo "== Cursor hooks.json absent before install -> created -> gone after uninstall"
rm -f "$CURSOR_HOOKS"
bash "$REPO/install.sh" --theme human </dev/null >/dev/null 2>&1 || fail "install exit 0"
check "created with version 1"             test "$(jqh '.version')" = "1"
bash "$REPO/install.sh" --uninstall </dev/null >/dev/null 2>&1
check "file removed (nothing of the user's was in it)" test ! -e "$CURSOR_HOOKS"
check "empty ~/.copilot/hooks dir removed" test ! -d "$HOME/.copilot/hooks"

echo "== Cursor hooks.json unparseable -> left alone, installer says so and still finishes"
printf '{ this is not json' > "$CURSOR_HOOKS"
bash "$REPO/install.sh" --theme human </dev/null >"$T/install4.log" 2>&1; rc=$?
check "installer exit 0"                   test "$rc" = "0"
check "file untouched"                     test "$(cat "$CURSOR_HOOKS")" = "{ this is not json"
check "installer prints a note"            grep -q 'could not update' "$T/install4.log"
check "installer does not claim success"   bash -c "! grep -q 'Cursor send hook installed' '$T/install4.log'"
check "no temp file left in \$TMPDIR"      bash -c "! ls '$T'/tmp.* >/dev/null 2>&1"
rm -f "$CURSOR_HOOKS"

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
