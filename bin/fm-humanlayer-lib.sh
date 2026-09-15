#!/usr/bin/env bash

# Plain transcript-shaped input cannot prove completion. Only the styled
# vendor completion row can retire an earlier prompt; a literal > inside a
# multiline draft must not establish an empty composer.
fm_humanlayer_screen_state() {
  awk '
    BEGIN { esc = sprintf("%c", 27) }
    {
      completed = $0 ~ ("^" esc "\\[38;2;(34;197;94|239;68;68|234;179;8)m\\[Done\\]" esc "\\[39m")
      gsub(esc "\\[[0-9;]*m", "")
      if (completed) { pending = 0; composer = 0 }
      else if ($0 ~ /^>/) {
        composer = 1
        if ($0 !~ /^>[[:space:]]*$/) pending = 1
      } else if (composer && $0 ~ /[^[:space:]]/) pending = 1
      if ($0 ~ /[^[:space:]]/) last = $0
    }
    END { print !pending && last ~ /^>[[:space:]]*$/ ? "idle" : "unknown" }
  '
}

# Prefer styling where the backend exposes it. Plain captures deliberately
# cannot clear ambiguous prompt history using a pasted completion marker.
fm_humanlayer_capture() {  # <backend> <target> [expected-label]
  if command -v fm_backend_source >/dev/null 2>&1; then
    fm_backend_source "$1" || return 1
  fi
  case "$1" in
    tmux) tmux capture-pane -e -p -J -t "$2" -S - 2>/dev/null ;;
    herdr) fm_backend_herdr_capture_ansi "$2" 200 "${3:-}" 2>/dev/null ;;
    zellij) fm_backend_zellij_composer_capture "$2" "${3:-}" 2>/dev/null ;;
    *) fm_backend_capture "$1" "$2" 200 "${3:-}" ;;
  esac
}

fm_humanlayer_submission_seen() {
  FM_HL_SUBMIT_TEXT="$1" awk '
    BEGIN { count = split(ENVIRON["FM_HL_SUBMIT_TEXT"], text, "\n") }
    submitted && remaining > 0 {
      if ($0 != text[count - remaining + 1]) submitted = 0
      remaining--
      next
    }
    /^>[[:space:]]*$/ { next }
    /^>/ { submitted = ($0 == "> " text[1]); remaining = count - 1; confirmed = 0; next }
    submitted && /^\[(Tool|Assistant|Done)\]/ { confirmed = 1 }
    END { exit !confirmed }
  '
}

fm_humanlayer_processes_active() {
  FM_HL_FOREGROUND_PIDS="$1" awk '
    BEGIN {
      count = split(ENVIRON["FM_HL_FOREGROUND_PIDS"], ids, /[[:space:]]+/)
      for (i = 1; i <= count; i++) foreground[ids[i]] = 1
    }
    NF >= 5 {
      parent[$1] = $2; status[$1] = $4
      name[$1] = $5; sub(/^.*\//, "", name[$1])
      if (foreground[$1] && name[$1] == "humanlayer" && $4 !~ /[ZTX]/) root[$1] = 1
    }
    END {
      for (pid in parent) {
        if (status[pid] ~ /[ZTX]/ || name[pid] ~ /^(humanlayer|node|codex)$/) continue
        ancestor = parent[pid]
        for (depth = 0; depth < 128 && ancestor > 1; depth++) {
          if (root[ancestor]) exit 0
          ancestor = parent[ancestor]
        }
      }
      exit 1
    }
  '
}
