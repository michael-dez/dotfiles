#!/usr/bin/env bash
# bcpc -- Sunshine global_prep_cmd "undo": tear down stream-start.sh. Deliberately not `set -e`: teardown must
# reach `output remove`. Also a keybind. Why: docs/streaming.md#stream-endsh

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

hyprctl_logged() {
    local out rc=0
    out=$(hyprctl "$@" 2>&1) || rc=$?
    hook_log "hyprctl $* -> rc=$rc${out:+ | $out}"
    return 0
}

restore_to=""
if [ -r "$SUNSHINE_PREV_FOCUS" ]; then
    restore_to=$(cat "$SUNSHINE_PREV_FOCUS")
fi

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

    on_stream=$(
        hyprctl -j workspaces 2>/dev/null |
            jq -r --arg m "$SUNSHINE_MONITOR" '.[] | select(.monitor == $m) | .id'
    )
    hook_log "workspaces on $SUNSHINE_MONITOR: $(printf '%s ' $on_stream)"
    for ws in $on_stream; do
        hyprctl_logged dispatch "hl.dsp.workspace.move({ workspace = $ws, monitor = \"$restore_to\" })"
    done
else
    hook_log "no monitor besides $SUNSHINE_MONITOR, skipping moves"
    echo "sunshine hook: no monitor besides $SUNSHINE_MONITOR, removing it anyway" >&2
fi

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

"$(dirname "$(readlink -f "$0")")/stream-mode.sh" game || true

rm -f "$SUNSHINE_VIDEO_MODE" "$SUNSHINE_SESSION_MODE"

hook_log "teardown complete: $(hyprctl -j monitors 2>/dev/null | jq -c '[.[].name]' 2>/dev/null || echo 'query failed')"
