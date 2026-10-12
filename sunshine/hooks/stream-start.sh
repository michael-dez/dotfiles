#!/usr/bin/env bash
# bcpc -- Sunshine global_prep_cmd "do": headless output sized to the client, workspace 11 on it. Undone by stream-end.sh.
# Why (no resolution fallback, focus captured first, X11 primary flip): docs/streaming.md#stream-startsh

set -euo pipefail

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

hyprctl_logged() {
    local out rc=0
    out=$(hyprctl "$@" 2>&1) || rc=$?
    hook_log "hyprctl $* -> rc=$rc${out:+ | $out}"
    return "$rc"
}

case "${SUNSHINE_APP_NAME:-}" in
    *[Dd]esktop*) session_mode="desktop" ;;
    *)            session_mode="game" ;;
esac
hook_log "app '${SUNSHINE_APP_NAME:-unset}' (id ${SUNSHINE_APP_ID:-unset}) -> $session_mode mode"

"$(dirname "$(readlink -f "$0")")/stream-mode.sh" "$session_mode" || true

width=${SUNSHINE_CLIENT_WIDTH:-}
height=${SUNSHINE_CLIENT_HEIGHT:-}
fps=${SUNSHINE_CLIENT_FPS:-60}

video_mode=""
if [ -n "$width" ] && [ -n "$height" ]; then
    video_mode="${width}x${height}@${fps}"
    printf '%s\n' "$video_mode" > "$SUNSHINE_VIDEO_MODE" 2>/dev/null || true
    hook_log "client mode $video_mode (env: w=$width h=$height fps=${SUNSHINE_CLIENT_FPS:-unset})"
else
    rm -f "$SUNSHINE_VIDEO_MODE"
    hook_log "NO client mode in the environment (w=${SUNSHINE_CLIENT_WIDTH:-unset} h=${SUNSHINE_CLIENT_HEIGHT:-unset}); leaving the output at the size stream.lua gave it"
fi

hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' > "$SUNSHINE_PREV_FOCUS" || true
hook_log "prev focus recorded: $(cat "$SUNSHINE_PREV_FOCUS" 2>/dev/null || echo '(none)')"

monitor_exists() {
    hyprctl -j monitors all |
        jq -e --arg m "$SUNSHINE_MONITOR" 'any(.[]; .name == $m)' >/dev/null
}

if ! monitor_exists; then
    hyprctl_logged output create headless "$SUNSHINE_MONITOR"

    waited=0
    for _ in $(seq 20); do
        monitor_exists && break
        waited=$((waited + 1))
        sleep 0.1
    done
    hook_log "output create: appeared after ${waited} poll(s) of 0.1s"

    if ! monitor_exists; then
        hook_log "BAIL: $SUNSHINE_MONITOR did not appear after 2s, streaming a physical display"
        echo "sunshine hook: $SUNSHINE_MONITOR did not appear, streaming a physical display" >&2
        exit 0
    fi
else
    hook_log "output $SUNSHINE_MONITOR already existed, reusing"
fi

if [ -n "$video_mode" ]; then
    hyprctl_logged eval "hl.monitor({ output = \"$SUNSHINE_MONITOR\", mode = \"$video_mode\", position = \"auto\", scale = 1 })"
fi

hyprctl_logged dispatch "hl.dsp.focus({ monitor = \"$SUNSHINE_MONITOR\" })"
hyprctl_logged dispatch "hl.dsp.focus({ workspace = $SUNSHINE_WORKSPACE })"
hyprctl_logged dispatch "hl.dsp.workspace.move({ workspace = $SUNSHINE_WORKSPACE, monitor = \"$SUNSHINE_MONITOR\" })"

hook_log "post-setup: $(hyprctl -j monitors 2>/dev/null | jq -c '[.[] | {name, focused, ws: .activeWorkspace.id}]' 2>/dev/null || echo 'query failed')"

if [ -n "${SUNSHINE_XDISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
    DISPLAY=$SUNSHINE_XDISPLAY xrandr --query 2>/dev/null |
        awk '/ connected primary/{print $1; exit}' > "$SUNSHINE_PREV_PRIMARY" || true
    hook_log "x11 primary was: $(cat "$SUNSHINE_PREV_PRIMARY" 2>/dev/null || echo '(none)')"

    if DISPLAY=$SUNSHINE_XDISPLAY xrandr --output "$SUNSHINE_MONITOR" --primary 2>/dev/null; then
        hook_log "x11 primary -> $SUNSHINE_MONITOR ($(DISPLAY=$SUNSHINE_XDISPLAY xrandr --query 2>/dev/null | awk '/ connected primary/{print $1; exit}'))"
    else
        hook_log "x11 primary flip FAILED (display=$SUNSHINE_XDISPLAY)"
    fi
else
    hook_log "skipping x11 primary flip (xdisplay='${SUNSHINE_XDISPLAY:-}', xrandr present: $(command -v xrandr >/dev/null 2>&1 && echo yes || echo no))"
fi
