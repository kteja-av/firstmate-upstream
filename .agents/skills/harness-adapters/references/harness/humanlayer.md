# HumanLayer CLI (codelayer)

The HumanLayer CLI's `codelayer` multi-provider coding agent TUI, verified end to end on 2026-09-15 with humanlayer 0.31.0 (`~/.local/bin/humanlayer`, config home `~/.humanlayer`) on macOS arm64 through the tmux backend, with the Codex provider (`--provider codex`, model default `gpt-6-astra`).
Verified as a CREWMATE and SCOUT adapter only; `../../../../../bin/fm-spawn.sh` refuses a secondmate launch on it because `../../../../../docs/supervision-protocols/` carries no humanlayer wake protocol.
`../../../../../docs/verification/runtime-backends.md` ("HumanLayer") owns how every fact below was established and what is still unproven.

## Operating facts

| Fact | Value |
|---|---|
| Binary | Absolute `humanlayer` from `PATH`, refused if absent; the installed launcher is a node shim (`~/.local/bin/humanlayer`) whose native child (`.../@humanlayer/cli-darwin-arm64/bin/humanlayer`) has `comm` exactly `humanlayer`. |
| Launch | `humanlayer codelayer --provider codex`, bare: there is no interactive launch flag that carries a prompt (`--prompt` runs non-interactively and exits at turn end), so the brief pointer is submitted through the composer after the readiness gate - the kimi/rovo launch-then-confirm shape. |
| Provider | `--provider codex` is the verified provider; codelayer's provider auto-runs tool calls with no approval prompt (verified live: bash commands and file writes landed ungated), which an unattended crewmate needs. |
| Busy state | No hook or plugin writer, so nothing is armed and no record is seeded; the verified anchor is the pinned bare `>` composer row, folded in `../../../../../bin/fm-busy-lib.sh` (`humanlayer-anchor`). |
| Idle anchor | At idle the bottom-most non-blank pane row is exactly the bare `>` composer; a running turn replaces it with streaming `[Tool]`/`[Assistant]` rows or the submitted prompt's echo row, and re-renders the bare `>` the moment the turn settles. |
| Turn end | No turn-end hook or notification touch exists; completion arrives through the worker status protocol, and the bare `>` anchor returning is the pane-side evidence. |
| Exit | No verified exit COMMAND: typed `/quit` and `/exit` reach the model as ordinary chat (the agent replied "Goodbye!" and stayed alive). Exit is a KEY - a single `Ctrl+C` at the idle composer exits the process - owned by `fm_control_exit_key` in `../../../../../bin/fm-control-lib.sh`. |
| Interrupt | Single `Ctrl+C` while a turn runs prints `[Done] Agent interrupted` and leaves an idle bare-`>` composer with no repollution; `Escape` is a no-op while a turn runs. The same `Ctrl+C` exits at the idle composer, so interrupt-then-exit is two presses for a busy agent, one for an idle one. |
| Skill | No verified slash-skill form: typed `/...` renders literal composer text and reaches the model as chat. Use natural language. |
| Autonomy | No approval flag exists or is needed; the codex provider ran every tool call ungated. |
| Marker | None; tool children inherit the launching environment unchanged (verified live: a codelayer tool subprocess carried the launcher's `PI_CODING_AGENT` and `AI_AGENT` with no `HUMANLAYER_*` or `CODELAYER_*` variable added), so the spawn template clears foreign primary markers and detection is ancestry alone. |
| Resume | No verified pane-resume contract; use deterministic relaunch. |
| Model | `--model <id>`; the codex provider defaults to `gpt-6-astra`. No reachable model-listing command exists (`humanlayer agents auth` manages authentication only), so a requested id launches unvalidated. |
| Effort | `--thinking low|medium|high|xhigh` (verified low and xhigh live); `max` is known-bad - the provider rejects it with "OpenAI Responses does not support reasoning effort max" - so it stays in task metadata under the record-and-omit contract. |
| Composer | Borderless bare `>` row, which the shared shape classifier reads as `unknown` under the dead-shell rule, never `empty`; spawn readiness, delivery, and steering confirm through the verified anchor instead, the agy precedent. |
| Multi-line | A multi-line steer typed with literal newlines lands in the composer without submitting and one `Enter` submits it as a single message (verified live). |

## Trust, approvals, and provider auth

A fresh task worktree showed no trust dialog of any kind (verified live across several fresh directories), so no trust pre-registration exists or is needed.
No approval prompt ever rendered: the codex provider ran `bash` commands and file writes without a gate, so there is no approval flow to map onto firstmate's decision plane.
`humanlayer api approvals resolve` exists in the cloud API surface for the HumanLayer app, not the local codelayer TUI, and is deliberately out of scope for this adapter.
The provider authenticated through the captain's own HumanLayer setup (`humanlayer agents auth codex` / AgentLayer file auth); any auth prompt or refusal is a credential blocker, not an adapter defect.

## Steering a busy worker is a documented gap

Text typed while a turn runs lands in a hidden input buffer and `Enter` does not queue it: the message was silently lost when the turn completed (verified live, humanlayer 0.31.0 - no echo row, no response, no error).
A steer delivered through `../../../../../bin/fm-send.sh` while the worker reads busy therefore fails loudly rather than degrading: the composer never returns a proven verdict and fm-send reports delivery unconfirmed, and the durable inbox record stays pending for the watcher's re-ring ladder.
Never treat a busy humanlayer worker as safely steerable; wait for the bare `>` idle anchor or use the control plane.

## Detection

Detected by ancestry alone: `../../../../../bin/fm-harness.sh` matches the anchored process name `humanlayer` (the native child) at comm strength, and the node shim through its script path in the interpreter-args arm.
No environment marker is promoted: codelayer adds no identity variable of its own and does not clear an inherited `CLAUDECODE` - but a structural humanlayer ancestor now outranks that retained marker.
The spawn template clears foreign primary markers at the launch boundary as defense in depth, the cursor/agy shape.
humanlayer is deliberately absent from the session-lock name vocabulary in `../../../../../bin/fm-session-lock-lib.sh`, where muse, gemini, and rovo are also absent: a crewmate-only adapter must never own a home session lock.

## Primary integration

Unsupported and unverified.
`../../../../../docs/supervision-protocols/` carries no humanlayer protocol, no turn-end guard adapter exists for it, and this adapter verified only the crewmate-side launch, busy state, interrupt, and exit.
`references/common/primary-hooks.md`'s unsupported-boundary rule applies: never invent a wake protocol from a similar TUI.

## Non-interactive mode

`humanlayer codelayer --provider codex --prompt "<prompt>"` runs one turn to completion, exits 0, and prints the final assistant message between the machine-readable markers `__CODELAYER_FINAL_MESSAGE_START__` and `__CODELAYER_FINAL_MESSAGE_END__` followed by `[Done] complete`.
This mode is deliberately NOT the worker shape: a pane whose process exits at turn end cannot receive steers, so the interactive TUI is the verified executor and `--prompt` remains a diagnostic tool.
