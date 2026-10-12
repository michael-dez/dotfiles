#!/usr/bin/env bash
# bcpc -- put the stream into game or desktop behaviour.   Usage: stream-mode.sh game|desktop
# Called from stream-start.sh and the Desktop app's prep-cmd (idempotent). Why: docs/streaming.md#stream-modesh

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

mode="game"
[ "${1:-}" = "desktop" ] && mode="desktop"

printf '%s\n' "$mode" > "$SUNSHINE_SESSION_MODE" 2>/dev/null || true

out=$(hyprctl eval "package.loaded.stream.set_mode(\"$mode\")" 2>&1) || true
hook_log "set_mode($mode) -> ${out:-no output}"

"$(dirname "$(readlink -f "$0")")/desktop-audio.sh" \
    "$([ "$mode" = "desktop" ] && echo on || echo off)"
