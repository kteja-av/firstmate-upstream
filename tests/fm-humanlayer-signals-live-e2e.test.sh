#!/usr/bin/env bash
# Live drift guard for the HumanLayer CLI adapter's vendor-controlled surface:
# process identity, the pinned bare-`>` busy anchor, interrupt, and exit.
# Opt-in because it submits real prompts (the codex provider is a live model;
# there is no echo provider for humanlayer).
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HL_BIN=$(command -v humanlayer 2>/dev/null || true)
REAL_TMUX=$(command -v tmux 2>/dev/null || true)
LAB=
SOCKET="fm-humanlayer-signals-$$"
SESSION=humanlayer-signals
TARGET="$SESSION:humanlayer"

cleanup() {
  [ -n "$REAL_TMUX" ] && "$REAL_TMUX" -L "$SOCKET" kill-server >/dev/null 2>&1 || true
  [ -z "$LAB" ] || rm -rf -- "$LAB"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  cleanup
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

fm_live_gate opt-in FM_HUMANLAYER_SIGNALS_LIVE humanlayer tmux
[ -n "$HL_BIN" ] || fail "humanlayer is not installed"

LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-humanlayer-signals.XXXXXX") || fail "could not create the isolated humanlayer lab"
trap cleanup EXIT
mkdir -p "$LAB/workspace" || fail "could not create the isolated lab workspace"
git -C "$LAB/workspace" init -q || fail "could not initialize the isolated humanlayer workspace"
git -C "$LAB/workspace" config user.email "guard@local" || fail "could not configure the isolated humanlayer workspace"
git -C "$LAB/workspace" config user.name "guard" || fail "could not configure the isolated humanlayer workspace"
git -C "$LAB/workspace" commit -q --allow-empty -m init || fail "could not seed the isolated humanlayer workspace"
WORKSPACE=$(cd "$LAB/workspace" && pwd -P) || fail "could not resolve the isolated humanlayer workspace"

# shellcheck source=/dev/null
. "$ROOT/bin/fm-busy-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-composer-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-control-lib.sh"

"$REAL_TMUX" -L "$SOCKET" new-session -d -s "$SESSION" -n humanlayer -c "$WORKSPACE" \
  || fail "could not start the isolated tmux server"

capture() {
  "$REAL_TMUX" -L "$SOCKET" capture-pane -p -J -t "$TARGET" -S - 2>/dev/null || true
}

last_nonblank() {
  printf '%s' "$1" | grep -v '^[[:space:]]*$' | tail -1
}

# Launch the interactive codelayer TUI on the verified provider. The TUI draws
# its provider banner and then the pinned bare `>` composer row.
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" -l \
  "$HL_BIN codelayer --provider codex" \
  || fail "could not type the humanlayer launch line"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" Enter \
  || fail "could not submit the humanlayer launch line"

ready=
for _ in $(seq 1 120); do
  screen=$(capture)
  if printf '%s\n' "$screen" | grep -Fq 'codelayer - provider:' \
    && [ "$(last_nonblank "$screen")" = '>' ]; then
    ready=1
    break
  fi
  sleep 0.5
done
[ -n "$ready" ] || fail "the real humanlayer TUI never rendered its banner plus bare-> composer"
pass "the real humanlayer TUI reaches its verified ready signal"

prompt="Add 12345 and 67890. Reply with exactly the sum and nothing else"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" -l "$prompt" \
  || fail "could not type the launch prompt"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" Enter \
  || fail "could not submit the launch prompt"

busy_live=
for _ in $(seq 1 120); do
  screen=$(capture)
  printf '%s' "$screen" | fm_humanlayer_submission_seen "$prompt" && { busy_live=1; break; }
  sleep 0.5
done
[ -n "$busy_live" ] || fail "the real humanlayer turn never produced submission evidence"
pass "the real humanlayer turn produces submission evidence"

idle_settled=
for _ in $(seq 1 240); do
  screen=$(capture)
  [ "$(last_nonblank "$screen")" = '>' ] && { idle_settled=1; break; }
  sleep 0.5
done
[ -n "$idle_settled" ] || fail "the humanlayer anchor never returned after the reply"
case "$screen" in
  *80235*|*80,235*) pass "the real humanlayer worker processed its prompt and settled idle" ;;
  *) fail "the real humanlayer worker never answered its prompt" ;;
esac
printf '%s' "$screen" | fm_busy_humanlayer_tail_idle \
  || fail "the settled humanlayer tail must read idle through fm_busy_humanlayer_tail_idle"
pass "the settled humanlayer tail reads idle through the anchor fold"

# Interrupt a genuinely long turn: poll until busy is observed, then send
# exactly one Ctrl+C - the adapter's verified interrupt key - and wait for the
# `[Done] Agent interrupted` row it prints; a busy anchor that merely
# disappears is not cancellation and no further key is sent.
prompt="Run: sleep 90; then reply LATE-GUARD"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" -l "$prompt" \
  || fail "could not type the long humanlayer prompt"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" Enter \
  || fail "could not submit the long humanlayer prompt"
for _ in $(seq 1 100); do
  screen=$(capture)
  printf '%s' "$screen" | fm_humanlayer_submission_seen "$prompt" && break
  sleep 0.5
done
printf '%s' "$screen" | fm_humanlayer_submission_seen "$prompt" \
  || fail "the long humanlayer turn never produced submission evidence"
[ "$(last_nonblank "$screen")" != '>' ] \
  || fail "the long humanlayer turn already settled before interruption"
process_busy=
for _ in $(seq 1 40); do
  pane_tty=$("$REAL_TMUX" -L "$SOCKET" display-message -p -t "$TARGET" '#{pane_tty}')
  foreground=$(ps -t "${pane_tty#/dev/}" -o pid=,pgid=,tpgid= \
    | awk '$2 == $3 { print $1 }')
  if ps -axo pid=,ppid=,pgid=,stat=,comm= | fm_humanlayer_processes_active "$foreground"; then
    process_busy=1
    break
  fi
  sleep 0.5
done
[ -n "$process_busy" ] || fail "HumanLayer did not expose the running tool as foreground worker activity"
pass "HumanLayer running-tool activity is attributable to its foreground process"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" C-c \
  || fail "could not send Ctrl+C to the real humanlayer turn"
cancelled=
for _ in $(seq 1 120); do
  screen=$(capture)
  case "$screen" in *"Agent interrupted"*) cancelled=1; break ;; esac
  sleep 0.5
done
[ -n "$cancelled" ] || fail "a single Ctrl+C never cancelled the real humanlayer turn"
pass "a single Ctrl+C cancels the real humanlayer turn"

# The same key at the now-idle composer exits the process: the verified
# key-based exit, and the fact fm_control_exit_key records.
idle=
for _ in $(seq 1 60); do
  screen=$(capture)
  [ "$(last_nonblank "$screen")" = '>' ] && { idle=1; break; }
  sleep 0.5
done
[ -n "$idle" ] || fail "the humanlayer composer never settled idle after the interrupt"
"$REAL_TMUX" -L "$SOCKET" send-keys -t "$TARGET" C-c \
  || fail "could not send the Ctrl+C exit key"
gone=
for _ in $(seq 1 60); do
  current=$("$REAL_TMUX" -L "$SOCKET" display-message -p -t "$TARGET" '#{pane_current_command}' 2>/dev/null || true)
  case "$current" in
    *humanlayer*|*node*) sleep 0.5 ;;
    *) gone=1; break ;;
  esac
done
[ -n "$gone" ] || fail "the Ctrl+C exit key never stopped the real humanlayer process"
pass "a single Ctrl+C at the idle composer stops the real humanlayer process"

cleanup
trap - EXIT
