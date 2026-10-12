#!/usr/bin/env bash
# bcpc -- Sunshine prep "undo": re-arm ollama.socket after a stream, only if suspend flagged it up.
# Why: docs/llm.md#stream-hooks

set -u

OLLAMA_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$OLLAMA_HOOK_LOG")" 2>/dev/null

hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$OLLAMA_HOOK_LOG" 2>/dev/null || true
}

OLLAMA_WAS_UP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ollama-was-up"

if [ ! -e "$OLLAMA_WAS_UP" ]; then
    hook_log "no suspend flag, leaving ollama as-is"
    exit 0
fi

rm -f "$OLLAMA_WAS_UP"

if timeout 20 systemctl start ollama.socket; then
    hook_log "re-armed ollama.socket (service starts on next request)"
else
    hook_log "FAILED to start ollama.socket (rc=$?) -- check the polkit rule"
fi

exit 0
