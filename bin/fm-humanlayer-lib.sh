#!/usr/bin/env bash

fm_humanlayer_screen_state() {
  awk '
    /[^[:space:]]/ { last = $0 }
    END { print last ~ /^>[[:space:]]*$/ ? "idle" : "unknown" }
  '
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
      parent[$1] = $2; group[$1] = $3; status[$1] = $4
      name[$1] = $5; sub(/^.*\//, "", name[$1])
      if (foreground[$1] && name[$1] == "humanlayer" && $4 !~ /[ZTX]/) root[$1] = 1
    }
    END {
      for (pid in parent) {
        if (status[pid] ~ /[ZTX]/ || name[pid] ~ /^(humanlayer|node|codex)$/) continue
        ancestor = parent[pid]
        for (depth = 0; depth < 128 && ancestor > 1; depth++) {
          if (root[ancestor] && group[pid] == group[ancestor]) exit 0
          ancestor = parent[ancestor]
        }
      }
      exit 1
    }
  '
}
