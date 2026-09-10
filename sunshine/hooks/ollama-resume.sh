#!/usr/bin/env bash
# bcpc -- Sunshine prep "undo": re-arm ollama after the stream ends.
#
# Starts ollama.socket and nothing else. That is the whole restore: the socket
# is the on-demand entry point, so the first request after the stream brings
# ollama.service and ollama-proxy.service up behind it. Starting ollama.service
# here instead would leave it running for the rest of the boot regardless of
# whether anything ever asked, which is the exact behaviour the socket exists to
# avoid.
#
# Undoes ollama-suspend.sh. Also runs when a client vanishes without
# disconnecting cleanly, which is why it has to tolerate the suspend half never
# having run.

set -u

OLLAMA_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$OLLAMA_HOOK_LOG")" 2>/dev/null

hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$OLLAMA_HOOK_LOG" 2>/dev/null || true
}

OLLAMA_WAS_UP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ollama-was-up"

# The flag is the record of what this hook is allowed to undo. No flag means
# either ollama was already down when the stream started, or the suspend hook
# never ran at all -- in both cases the honest action is none. Restoring a
# service the user had stopped by hand, every time a stream ends, is the failure
# mode this guards against.
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
