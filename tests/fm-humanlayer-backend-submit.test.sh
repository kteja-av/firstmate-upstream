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
  if [ -f "$TEST_TMP/response" ]; then
    cat "$TEST_TMP/response"
    rm -f "$TEST_TMP/response"
  else
    printf '%s' "$fixture_screen"
  fi
}
submit_fixture() {
  [ "$1" = endpoint ] && [ "$6" = worker-label ] && [ "$7" = humanlayer ] || return 1
  submissions=$((submissions + 1))
  : > "$TEST_TMP/submitted"
  printf empty
}
literal_fixture() {
  [ "$1" = endpoint ] && [ "$3" = worker-label ] || return 1
  submissions=$((submissions + 1))
  : > "$TEST_TMP/submitted"
  printf '%s' "$2" > "$TEST_TMP/text"
}
key_fixture() {
  [ "$1" = endpoint ] && [ "$2" = Enter ] && [ "$3" = worker-label ] || return 1
  printf 'Enter\n' >> "$TEST_TMP/keys"
  local plain
  plain=$(printf '%s' "$fixture_screen" | fm_composer_strip_ansi | tr -d '\r')
  {
    printf '%s> %s\n' "${plain%>*}" "$(cat "$TEST_TMP/text")"
    case "${delivery:-working}" in
      working) printf '[Tool] bash command=work\n' ;;
      complete) printf '[Assistant] done\n[Done] complete\n>\n' ;;
    esac
  } > "$TEST_TMP/response"
}
fm_backend_herdr_send_literal() { literal_fixture "$@"; }
fm_backend_cmux_send_literal() { literal_fixture "$@"; }
fm_backend_orca_send_literal() { literal_fixture "$@"; }
fm_backend_herdr_send_key() { key_fixture "$@"; }
fm_backend_cmux_send_key() { key_fixture "$@"; }
fm_backend_orca_send_key() { key_fixture "$@"; }
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


banner=$'[codex-provider] using sse transport http://localhost/session\ncodelayer - provider: codex, model: gpt-6-astra'
for backend in tmux herdr cmux orca zellij; do
  capture_ok=yes
  fixture_screen="$banner"$'\n>\n'
  submissions=0
  rm -f "$TEST_TMP/submitted"
  fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null \
    || fail "$backend must accept the verified fresh-launch composer"
  [ "$submissions" = 1 ] || fail "$backend must deliver the fresh-launch instruction once"
  fm_task_inbox_ring "$backend" endpoint record worker-label humanlayer \
    || fail "$backend must ring the verified fresh-launch composer"
  for fixture_screen in "$banner"$'\nretained log\n>' $'retained log\n'"$banner"$'\n>' "$banner"$'\n> draft\n>' "$banner"$'\n>\n>' $'codelayer - provider: codex, model: gpt-6-astra\n>' "$banner"$'\n\n>'; do
    submissions=0
    rm -f "$TEST_TMP/submitted"
    if fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null; then
      fail "$backend must reject incomplete or displaced startup provenance"
    fi
    [ "$submissions" = 0 ] || fail "$backend must preserve ambiguous startup content"
    if fm_task_inbox_ring "$backend" endpoint record worker-label humanlayer; then
      fail "$backend inbox must reject ambiguous startup content"
    fi
    [ ! -e "$TEST_TMP/submitted" ] || fail "$backend inbox must preserve ambiguous startup content"
  done
  pass "$backend accepts only the top-anchored fresh-launch banner and empty composer"
done


footer=$'  Model            Input   Output     Cost             Context\n  gpt-6-astra      5,534        13   ~$0.06  5,542/258,400 (2%)'
for completion in $'\033[38;2;34;197;94m[Done]\033[39m complete' $'\033[0m\033[38;2;34;197;94m[Done]\033[0m complete\r'; do
  for backend in tmux herdr cmux orca zellij; do
    capture_ok=yes
    settled_screen=$'> previous prompt\n'"$completion"$'\n'"$footer"
    fixture_screen="$settled_screen"$'\n>\n'
    submissions=0
    fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null \
      || fail "$backend must accept a completed turn with its usage footer"
    [ "$submissions" = 1 ] || fail "$backend must submit once after the usage footer"
    fm_task_inbox_ring "$backend" endpoint record worker-label humanlayer \
      || fail "$backend inbox must accept a settled usage footer"
    for fixture_screen in "$settled_screen" "$settled_screen"$'\n> draft\n>' "$settled_screen"$'\n>\n>' "$settled_screen"$'\n>\n'"$footer"$'\n>' $'> draft\n[Done] complete\n'"$footer"$'\n>' "$footer"$'\n>'; do
      submissions=0
      rm -f "$TEST_TMP/submitted"
      if fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer >/dev/null; then
        fail "$backend must not accept usage-shaped draft content or missing composer"
      fi
      [ "$submissions" = 0 ] || fail "$backend must preserve usage-shaped draft content"
      if fm_task_inbox_ring "$backend" endpoint record worker-label humanlayer; then
        fail "$backend inbox must defer usage-shaped draft content"
      fi
      [ ! -e "$TEST_TMP/submitted" ] || fail "$backend inbox must not submit usage-shaped draft content"
    done
    pass "$backend preserves completion through usage furniture and rejects new drafts"
  done
done


for backend in herdr cmux orca; do
  for delivery in working complete swallowed; do
    fixture_screen=$'> instruction\n[Assistant] old result\n\033[38;2;34;197;94m[Done]\033[39m complete\n>\n'
    : > "$TEST_TMP/keys"
    verdict=$(fm_backend_send_text_submit "$backend" endpoint instruction 1 0 0 worker-label humanlayer)
    if [ "$delivery" = swallowed ]; then
      [ "$verdict" = unknown ] || fail "$backend must not borrow historical confirmation"
    else
      [ "$verdict" = empty ] || fail "$backend must confirm current $delivery output"
    fi
    [ "$(wc -l < "$TEST_TMP/keys" | tr -d ' ')" = 1 ] || fail "$backend must send Enter once"
  done
  pass "$backend confirms current HumanLayer responses without generic composer state"
done
