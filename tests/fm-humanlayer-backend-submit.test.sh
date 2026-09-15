#!/usr/bin/env bash
set -eu
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
. "$ROOT/bin/fm-backend.sh"
. "$ROOT/bin/fm-task-inbox-lib.sh"

TEST_TMP=$(fm_test_tmproot fm-humanlayer-backend-submit)
fm_backend_source() { :; }
capture_fixture() {
  [ "$1" = endpoint ] && [ "$3" = worker-label ] || return 1
  [ "$capture_ok" = yes ] || return 1
  printf '%s' "$fixture_screen"
}
submit_fixture() {
  [ "$1" = endpoint ] && [ "$6" = worker-label ] && [ "$7" = humanlayer ] || return 1
  submissions=$((submissions + 1))
  : > "$TEST_TMP/submitted"
  printf empty
}
tmux() {
  [ "$1" = capture-pane ] || return 1
  while [ "$#" -gt 0 ] && [ "$1" != -t ]; do shift; done
  [ "$#" -ge 2 ] || return 1
  capture_fixture "$2" 200 worker-label
}
fm_backend_herdr_capture_ansi() { capture_fixture "$@"; }
fm_backend_zellij_composer_capture() { capture_fixture "$1" 200 "$2"; }
fm_backend_tmux_capture() { capture_fixture "$@"; }
fm_backend_herdr_capture() { capture_fixture "$@"; }
fm_backend_cmux_capture() { capture_fixture "$@"; }
fm_backend_orca_capture() { capture_fixture "$@"; }
fm_backend_zellij_capture() { capture_fixture "$@"; }
fm_backend_tmux_send_text_submit() { submit_fixture "$@"; }
fm_backend_herdr_send_text_submit() { submit_fixture "$@"; }
fm_backend_cmux_send_text_submit() { submit_fixture "$@"; }
fm_backend_orca_send_text_submit() { submit_fixture "$@"; }
fm_backend_zellij_send_text_submit() { submit_fixture "$@"; }
fm_backend_agent_state() { printf alive; }
fm_backend_composer_state() { printf unknown; }
fm_task_inbox_doorbell_line() { printf doorbell; }

for backend in tmux herdr cmux orca zellij; do
  for fixture_screen in $'>\n[Done] complete\n>' $'> Investigate this log:\n[Done] complete\n>' '> draft' $'> Investigate this log:\n[Done] complete\n\n' $'>\n[Assistant] draft' ''; do
    capture_ok=yes
    submissions=0
    rm -f "$TEST_TMP/submitted"
    if fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null; then
      fail "$backend must defer unsafe input"
    fi
    [ "$submissions" = 0 ] || fail "$backend must not call submit on unsafe input"
    if fm_task_inbox_ring "$backend" endpoint record worker-label humanlayer; then
      fail "$backend inbox must defer unsafe input"
    fi
    [ ! -e "$TEST_TMP/submitted" ] || fail "$backend inbox must not call submit on unsafe input"
  done
  fixture_screen=$'> previous prompt\n\033[38;2;34;197;94m[Done]\033[39m complete\n>\n'
  case "$backend" in cmux|orca) fixture_screen='>' ;; esac
  capture_ok=no
  if fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null; then
    fail "$backend must defer failed capture"
  fi
  capture_ok=yes
  submissions=0
  fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null
  [ "$submissions" = 1 ] || fail "$backend must submit once when affirmatively idle"
  fm_task_inbox_ring "$backend" endpoint record worker-label humanlayer || fail "$backend must ring an idle worker"
  pass "$backend HumanLayer submission requires an affirmatively empty composer"
done
