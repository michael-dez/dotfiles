#!/usr/bin/env bash
# bcpc -- Sunshine prep "do": get ollama off the GPU before the stream starts.
#
# Second entry in global_prep_cmd, independent of the Hyprland hooks. Kept as
# its own script rather than folded into stream-start.sh for one specific
# reason: stream-start.sh sources hyprctl-env.sh, which exits 0 when no live
# Hyprland instance is found. Anything appended there would be skipped in
# exactly the situation where it still matters -- a stream on a host whose
# compositor died -- and skipped silently.
#
# Why stop the service rather than let keep-alive expire: OLLAMA_KEEP_ALIVE is
# 5m (see system/ollama-override.conf), and the whole point of a stream hook is
# that the game wants the VRAM now. Stopping ollama.socket too is what keeps it
# down -- with the socket still armed, anything that touches the API restarts
# the whole chain, and a desktop LLM client left open in the background does
# exactly that on its own: they poll /api/tags to refresh the model list. That
# is a connection nobody made deliberately, restarting a service mid-game.
#
# Undone by ollama-resume.sh.
#
# Best-effort throughout, like every other hook here: a stream must never fail
# because a background service would not stop.

set -u

OLLAMA_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$OLLAMA_HOOK_LOG")" 2>/dev/null

# Same format as hyprctl-env.sh's hook_log, so both halves of a stream's
# lifecycle interleave readably in one file. Not sourced from there because
# sourcing that file also imports its bail-on-no-compositor behaviour.
hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$OLLAMA_HOOK_LOG" 2>/dev/null || true
}

# Whether ollama was actually up when the stream began. Written before anything
# is stopped and read by ollama-resume.sh, so that a stream cannot *start*
# ollama on a machine where it had been deliberately stopped -- an unconditional
# `systemctl start ollama.socket` at stream end would do exactly that.
#
# XDG_RUNTIME_DIR, matching SUNSHINE_PREV_FOCUS and friends: this is per-boot
# state, and a stale flag surviving a reboot would be worse than no flag.
OLLAMA_WAS_UP="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ollama-was-up"

if systemctl is-active --quiet ollama.socket || systemctl is-active --quiet ollama.service; then
    : > "$OLLAMA_WAS_UP"
    hook_log "ollama was up, suspending for the stream"
else
    rm -f "$OLLAMA_WAS_UP"
    hook_log "ollama already down, nothing to suspend"
    exit 0
fi

# Order matters: the socket first, so nothing can re-trigger activation in the
# gap, then the units it activates. ollama-proxy.service is BindsTo=ollama
# .service and would follow on its own, but naming it keeps this correct if that
# dependency is ever loosened.
#
# `timeout` because this runs on the critical path of a client connecting -- a
# systemctl call that blocks on a wedged unit would delay the stream by the full
# 90s default job timeout. Unloading a model and exiting takes well under a
# second in practice.
if timeout 20 systemctl stop ollama.socket ollama-proxy.service ollama.service; then
    hook_log "stopped ollama.socket, ollama-proxy.service, ollama.service"
else
    # The likely cause is the polkit rule not being installed (see
    # system/49-ollama-stream.rules): without it systemctl tries to prompt, and
    # from a hook with no agent attached that fails rather than blocking. Worth
    # naming, because the visible symptom is just a game with less VRAM.
    hook_log "FAILED to stop ollama (rc=$?) -- check the polkit rule; the stream continues"
fi

# Never fail the stream.
exit 0
