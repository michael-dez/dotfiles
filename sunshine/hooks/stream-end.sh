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

# Stop the fullscreen listener first, so it cannot react to windows shuffling
# around while the virtual output is torn down.
if [ -r "$SUNSHINE_FOCUS_PID" ]; then
    kill "$(cat "$SUNSHINE_FOCUS_PID")" 2>/dev/null
    rm -f "$SUNSHINE_FOCUS_PID"
fi

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
    restore_to=$(
        hyprctl -j monitors 2>/dev/null |
            jq -r --arg m "$SUNSHINE_MONITOR" \
                'map(select(.name != $m)) | .[0].name // empty'
    )
fi

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
        for addr in $(
            hyprctl -j clients 2>/dev/null |
                jq -r --arg ws "$SUNSHINE_WORKSPACE" \
                    '.[] | select((.workspace.id|tostring) == $ws) | .address'
        ); do
            hyprctl dispatch movetoworkspacesilent "$target_ws,address:$addr" || true
        done
    fi

    # Then move the (now ideally empty) workspace off the virtual output before
    # it disappears. Hyprland would relocate it on its own, but not predictably
    # to the monitor wanted.
    hyprctl dispatch moveworkspacetomonitor "$SUNSHINE_WORKSPACE" "$restore_to" || true
else
    # No physical monitor left to fall back to. Removing the virtual output is
    # still right -- Hyprland handles being left with none -- but skip the
    # moves, which would only fail.
    echo "sunshine hook: no monitor besides $SUNSHINE_MONITOR, removing it anyway" >&2
fi

hyprctl output remove "$SUNSHINE_MONITOR" || true

if [ -n "$restore_to" ]; then
    hyprctl dispatch focusmonitor "$restore_to" || true
fi
