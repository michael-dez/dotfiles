#!/usr/bin/env bash
# bcpc -- Sunshine global_prep_cmd "undo". Runs when a Moonlight client
# disconnects, including when the client dies without saying goodbye.
#
# Tears down what stream-start.sh built. Deliberately NOT `set -e`: a failure
# partway through would leave the virtual output alive with the reserved
# workspace stranded on it, and since that output is invisible, so is every
# window on it. Each step is best-effort so the teardown always reaches
# `output remove`.
#
# Also bound to a keybind in hypr/keybinds.conf as a manual escape hatch for
# when a crashed stream never fires this.

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

# Same wrapper as stream-start.sh, minus the abort semantics -- nothing here is
# allowed to stop the teardown, so this only ever records what happened.
hyprctl_logged() {
    local out rc=0
    out=$(hyprctl "$@" 2>&1) || rc=$?
    hook_log "hyprctl $* -> rc=$rc${out:+ | $out}"
    return 0
}

# No listener to stop: hypr/stream.lua keys off the headless output's existence,
# so removing that output at the bottom of this script is what disarms it. One
# less process to leak if this hook dies partway through.

# Where to put the workspace and the focus back. Prefer whatever had focus when
# the stream started; fall back to the first monitor that is not the virtual
# one. Resolved rather than hardcoded either way -- connector names differ per
# machine, and the layout here changes often enough that a literal DP-1 would
# rot.
restore_to=""
if [ -r "$SUNSHINE_PREV_FOCUS" ]; then
    restore_to=$(cat "$SUNSHINE_PREV_FOCUS")
fi

# Validate it: the remembered monitor may have been unplugged mid-stream, and
# it must never be the output that is about to be removed.
if [ -z "$restore_to" ] || [ "$restore_to" = "$SUNSHINE_MONITOR" ] ||
    ! hyprctl -j monitors 2>/dev/null |
        jq -e --arg m "$restore_to" 'any(.[]; .name == $m)' >/dev/null; then
    hook_log "recorded focus '$restore_to' unusable, falling back to first non-$SUNSHINE_MONITOR monitor"
    restore_to=$(
        hyprctl -j monitors 2>/dev/null |
            jq -r --arg m "$SUNSHINE_MONITOR" \
                'map(select(.name != $m)) | .[0].name // empty'
    )
fi
hook_log "restore target: ${restore_to:-(none)}"

rm -f "$SUNSHINE_PREV_FOCUS"

if [ -n "$restore_to" ]; then
    # Hand any surviving windows back to a workspace you can actually reach.
    # Moving the workspace alone is not enough: keybinds.conf binds 1-10 only,
    # so anything left sitting on workspace 11 is unreachable by keyboard once
    # the stream is over. Workspace 11 is an implementation detail of streaming
    # and has no business holding applications between sessions.
    target_ws=$(
        hyprctl -j monitors 2>/dev/null |
            jq -r --arg m "$restore_to" \
                '.[] | select(.name == $m) | .activeWorkspace.id // empty'
    )
    if [ -n "$target_ws" ] && [ "$target_ws" != "$SUNSHINE_WORKSPACE" ]; then
        stranded=$(
            hyprctl -j clients 2>/dev/null |
                jq -r --arg ws "$SUNSHINE_WORKSPACE" \
                    '.[] | select((.workspace.id|tostring) == $ws) | .address'
        )
        hook_log "evacuating $(printf '%s\n' "$stranded" | grep -c . ) window(s) from ws $SUNSHINE_WORKSPACE to ws $target_ws"
        for addr in $stranded; do
            hyprctl_logged dispatch "hl.dsp.window.move({ workspace = $target_ws, follow = false, window = \"address:$addr\" })"
        done
    else
        hook_log "no evacuation needed (target_ws='${target_ws:-}')"
    fi

    # Then move the (now ideally empty) workspace off the virtual output before
    # it disappears. Hyprland would relocate it on its own, but not predictably
    # to the monitor wanted.
    hyprctl_logged dispatch "hl.dsp.workspace.move({ workspace = $SUNSHINE_WORKSPACE, monitor = \"$restore_to\" })"
else
    # No physical monitor left to fall back to. Removing the virtual output is
    # still right -- Hyprland handles being left with none -- but skip the
    # moves, which would only fail.
    hook_log "no monitor besides $SUNSHINE_MONITOR, skipping moves"
    echo "sunshine hook: no monitor besides $SUNSHINE_MONITOR, removing it anyway" >&2
fi

# Hand X11's primary back before the output goes away -- an output that no
# longer exists cannot be named in an xrandr call. If nothing was primary to
# begin with, --noprimary is the honest restore; picking a monitor arbitrarily
# would leave the desk in a state the user never chose.
if [ -n "${SUNSHINE_XDISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
    prev_primary=$(cat "$SUNSHINE_PREV_PRIMARY" 2>/dev/null)
    if [ -n "$prev_primary" ]; then
        DISPLAY=$SUNSHINE_XDISPLAY xrandr --output "$prev_primary" --primary 2>/dev/null || true
        hook_log "x11 primary restored to $prev_primary"
    else
        DISPLAY=$SUNSHINE_XDISPLAY xrandr --noprimary 2>/dev/null || true
        hook_log "x11 primary cleared (none was set before the stream)"
    fi
fi
rm -f "$SUNSHINE_PREV_PRIMARY"

hyprctl_logged output remove "$SUNSHINE_MONITOR"

if [ -n "$restore_to" ]; then
    hyprctl_logged dispatch "hl.dsp.focus({ monitor = \"$restore_to\" })"
fi

hook_log "teardown complete: $(hyprctl -j monitors 2>/dev/null | jq -c '[.[].name]' 2>/dev/null || echo 'query failed')"
