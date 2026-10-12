# bcpc -- shared helper for the Sunshine stream hooks. Sourced, never executed.
# Re-derives a stale HYPRLAND_INSTANCE_SIGNATURE; exits the caller 0 if no live Hyprland. Defines hook_log and
# the state-file paths. Why: docs/streaming.md#hyprctl-envsh
SUNSHINE_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$SUNSHINE_HOOK_LOG")" 2>/dev/null

hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$SUNSHINE_HOOK_LOG" 2>/dev/null || true
}

if [ -f "$SUNSHINE_HOOK_LOG" ] &&
    [ "$(wc -l < "$SUNSHINE_HOOK_LOG" 2>/dev/null || echo 0)" -gt 2000 ]; then
    if tail -n 1000 "$SUNSHINE_HOOK_LOG" > "$SUNSHINE_HOOK_LOG.tmp" 2>/dev/null; then
        mv "$SUNSHINE_HOOK_LOG.tmp" "$SUNSHINE_HOOK_LOG" 2>/dev/null || true
    fi
fi

trap 'hook_log "exit $?"' EXIT

hook_log "start"

hypr_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"

hypr_socket_live() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] &&
        [ -S "$hypr_runtime/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]
}

if ! hypr_socket_live; then
    hook_log "HYPRLAND_INSTANCE_SIGNATURE stale or unset (was '${HYPRLAND_INSTANCE_SIGNATURE:-}'), re-deriving"
    for candidate in $(ls -1t "$hypr_runtime" 2>/dev/null); do
        if [ -S "$hypr_runtime/$candidate/.socket.sock" ]; then
            HYPRLAND_INSTANCE_SIGNATURE="$candidate"
            export HYPRLAND_INSTANCE_SIGNATURE
            hook_log "re-derived signature: $candidate"
            break
        fi
    done
fi

if ! hypr_socket_live; then
    hook_log "BAIL: no live Hyprland instance under $hypr_runtime, skipping hook entirely"
    echo "sunshine hook: no live Hyprland instance under $hypr_runtime, skipping" >&2
    exit 0
fi

SUNSHINE_MONITOR=sunshine

SUNSHINE_WORKSPACE=11

SUNSHINE_XDISPLAY=$(pgrep -a -x Xwayland 2>/dev/null |
    awk '{for (i = 1; i <= NF; i++) if ($i ~ /^:[0-9]+$/) { print $i; exit }}')

SUNSHINE_PREV_PRIMARY="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-prev-primary"

SUNSHINE_PREV_FOCUS="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-prev-focus"

SUNSHINE_VIDEO_MODE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-video-mode"
SUNSHINE_SESSION_MODE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-session-mode"
