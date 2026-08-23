#!/usr/bin/env bash
# bcpc -- Sunshine global_prep_cmd "do". Runs when a Moonlight client connects.
#
# Creates a headless Hyprland output sized to whatever the client asked for,
# parks the reserved workspace on it, and focuses it. Sunshine runs this before
# it launches the app, so the app's window opens on the focused workspace --
# which is now the virtual output. That ordering is what keeps the stream
# pointed at the game without any window rules or class matching.
#
# Undone by stream-end.sh.

set -euo pipefail

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

# Sunshine exports the client's negotiated video mode. The fallbacks are a
# Steam Deck OLED panel, which is what streams from here in practice.
width=${SUNSHINE_CLIENT_WIDTH:-1280}
height=${SUNSHINE_CLIENT_HEIGHT:-800}
fps=${SUNSHINE_CLIENT_FPS:-90}

monitor_exists() {
    hyprctl -j monitors all |
        jq -e --arg m "$SUNSHINE_MONITOR" 'any(.[]; .name == $m)' >/dev/null
}

if ! monitor_exists; then
    hyprctl output create headless "$SUNSHINE_MONITOR"

    # Creation is asynchronous -- the output shows up a frame or two later, and
    # setting its mode before it exists is a no-op that leaves the client at
    # whatever the default headless size is.
    for _ in $(seq 20); do
        monitor_exists && break
        sleep 0.1
    done

    if ! monitor_exists; then
        echo "sunshine hook: $SUNSHINE_MONITOR did not appear, streaming a physical display" >&2
        exit 0
    fi
fi

hyprctl keyword monitor "$SUNSHINE_MONITOR,${width}x${height}@${fps},auto,1"

# Remember where the focus was, so stream-end.sh can hand it back to the
# monitor actually in use rather than to whichever one enumerates first.
hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' > "$SUNSHINE_PREV_FOCUS" || true

# Order matters. Focus first, then switch: a workspace that holds no windows
# does not exist yet, so moving it before it is created just prints "Workspace
# not found". Switching to it while the virtual output has focus creates it
# there, and the `workspace = 11, monitor:sunshine` rule in hyprland.conf pins
# it. The move afterwards is the belt-and-braces case where workspace 11 did
# already exist on a physical monitor from an earlier stream.
hyprctl dispatch focusmonitor "$SUNSHINE_MONITOR"
hyprctl dispatch workspace "$SUNSHINE_WORKSPACE"
hyprctl dispatch moveworkspacetomonitor "$SUNSHINE_WORKSPACE" "$SUNSHINE_MONITOR"

# Start the fullscreen listener. Everything above only decides *where* windows
# land; this is what makes the stream show one window instead of a dwindle split
# of Steam beside the game. See stream-focus.py for why a window rule cannot do
# this on 0.56.
if [ -r "$SUNSHINE_FOCUS_PID" ] && kill -0 "$(cat "$SUNSHINE_FOCUS_PID")" 2>/dev/null; then
    :  # already running from an earlier connect; reuse it
else
    SUNSHINE_WORKSPACE="$SUNSHINE_WORKSPACE" \
        setsid "$(dirname "$(readlink -f "$0")")/stream-focus.py" >/dev/null 2>&1 &
    echo $! > "$SUNSHINE_FOCUS_PID"
fi
