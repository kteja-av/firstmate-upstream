#!/usr/bin/env bash

fm_humanlayer_screen_state() {
  awk '
    BEGIN { state = "unknown" }
    /^>[[:space:]]*$/ { state = "idle"; next }
    /^>/ { state = "unknown"; next }
    /^\[Done\]/ { state = "unknown"; next }
    /[^[:space:]]/ && state == "idle" { state = "unknown" }
    END { print state }
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
