#!/usr/bin/env bash
# bcpc -- Sunshine prep "do": stop ollama (and its socket) before a stream. Undone by ollama-resume.sh.
# Own script so it still runs when hyprctl-env.sh bails; always exits 0. Why: docs/llm.md#stream-hooks

set -u

OLLAMA_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$OLLAMA_HOOK_LOG")" 2>/dev/null

hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$OLLAMA_HOOK_LOG" 2>/dev/null || true
}

OLLAMA_WAS_UP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ollama-was-up"

if systemctl is-active --quiet ollama.socket || systemctl is-active --quiet ollama.service; then
    : > "$OLLAMA_WAS_UP"
    hook_log "ollama was up, suspending for the stream"
else
    rm -f "$OLLAMA_WAS_UP"
    hook_log "ollama already down, nothing to suspend"
    exit 0
fi

if timeout 20 systemctl stop ollama.socket ollama-proxy.service ollama.service; then
    hook_log "stopped ollama.socket, ollama-proxy.service, ollama.service"
else
    hook_log "FAILED to stop ollama (rc=$?) -- check the polkit rule; the stream continues"
fi

exit 0
