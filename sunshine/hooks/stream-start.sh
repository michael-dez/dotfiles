#!/usr/bin/env bash
# bcpc -- Sunshine global_prep_cmd "do". Runs when a Moonlight client connects.
#
# Creates a headless Hyprland output sized to whatever the client asked for,
# parks the reserved workspace on it, and focuses it. Sunshine runs this before
# it launches the app, so the app's window opens on the focused workspace --
# which is now the virtual output. That ordering is what keeps the stream
# pointed at the game without any window rules or class matching.
#
# It also decides which SESSION MODE the stream comes up in -- game for the
# Deck, desktop for Moonlight's "Desktop" app -- and does so before creating
# the output, so stream.lua's monitor.added handler already knows. See
# stream-mode.sh.
#
# Undone by stream-end.sh.

set -euo pipefail

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

# Run a hyprctl call and record what it did. Worth the wrapper because hyprctl
# reports failure only through its exit status -- it prints nothing useful --
# and under `set -e` a single failed call ends this script partway through with
# no evidence of which one it was.
#
# `|| rc=$?` keeps errexit from firing on the assignment itself, so the failure
# gets logged before it propagates. The return preserves the original abort.
hyprctl_logged() {
    local out rc=0
    out=$(hyprctl "$@" 2>&1) || rc=$?
    hook_log "hyprctl $* -> rc=$rc${out:+ | $out}"
    return "$rc"
}

# --- session mode ---------------------------------------------------------
# Sunshine names the app it is about to launch. "Desktop" is the tile BCLT taps
# to get a remote desktop instead of RDP; everything else is a game.
#
# Matched loosely on purpose -- a later "Desktop (1080p)" tile should not
# silently fall back to the game rules -- and defaulted to game, so an app name
# that never arrives lands on the behaviour this host has always had.
case "${SUNSHINE_APP_NAME:-}" in
    *[Dd]esktop*) session_mode="desktop" ;;
    *)            session_mode="game" ;;
esac
hook_log "app '${SUNSHINE_APP_NAME:-unset}' (id ${SUNSHINE_APP_ID:-unset}) -> $session_mode mode"

# Before the output exists: stream.lua's monitor.added handler reads the mode,
# and the workspace rules that decide whether workspace 11 has borders are
# applied when the workspace lands on the output a few lines below.
"$(dirname "$(readlink -f "$0")")/stream-mode.sh" "$session_mode" || true

# --- the client's mode ----------------------------------------------------
# Whatever the client asked for, full stop. This is the line that lets a Steam
# Deck in a dock stream at its television's resolution instead of at the Deck
# panel's: Moonlight negotiates the mode, Sunshine exports it, and the output is
# built to match.
#
# There is deliberately NO resolution fallback. The old one was a Deck OLED
# panel, which is precisely the assumption that made a docked client stream at
# the wrong size -- and a wrong size here is invisible from the host, because
# the output it describes is one nobody can see. If the mode is missing the
# output is left at whatever Hyprland gives it and this says so loudly, which
# is a better failure than a confident 1280x800. stream.lua's own fallback
# chain (the live output's mode, else "preferred") covers that case.
#
# fps alone keeps a fallback: it is the one field a mode string cannot omit,
# and 60 is true of every display that is not a handheld or a gaming panel.
width=${SUNSHINE_CLIENT_WIDTH:-}
height=${SUNSHINE_CLIENT_HEIGHT:-}
fps=${SUNSHINE_CLIENT_FPS:-60}

video_mode=""
if [ -n "$width" ] && [ -n "$height" ]; then
    video_mode="${width}x${height}@${fps}"
    # Read back by stream.lua on `hyprctl reload`, so a reload mid-stream
    # re-applies the client's mode rather than a config default.
    printf '%s\n' "$video_mode" > "$SUNSHINE_VIDEO_MODE" 2>/dev/null || true
    hook_log "client mode $video_mode (env: w=$width h=$height fps=${SUNSHINE_CLIENT_FPS:-unset})"
else
    rm -f "$SUNSHINE_VIDEO_MODE"
    hook_log "NO client mode in the environment (w=${SUNSHINE_CLIENT_WIDTH:-unset} h=${SUNSHINE_CLIENT_HEIGHT:-unset}); leaving the output at the size stream.lua gave it"
fi

# Remember where the focus was, so stream-end.sh can hand it back to the
# monitor actually in use rather than to whichever one enumerates first.
#
# Captured BEFORE the output is created, not after: creating a headless output
# moves focus onto it, so reading "the focused monitor" afterwards records
# `sunshine` itself and stream-end.sh then has nothing useful to restore to.
hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' > "$SUNSHINE_PREV_FOCUS" || true
hook_log "prev focus recorded: $(cat "$SUNSHINE_PREV_FOCUS" 2>/dev/null || echo '(none)')"

monitor_exists() {
    hyprctl -j monitors all |
        jq -e --arg m "$SUNSHINE_MONITOR" 'any(.[]; .name == $m)' >/dev/null
}

if ! monitor_exists; then
    hyprctl_logged output create headless "$SUNSHINE_MONITOR"

    # Creation is asynchronous -- the output shows up a frame or two later, and
    # setting its mode before it exists is a no-op that leaves the client at
    # whatever the default headless size is.
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

# `hyprctl keyword` is legacy-parser only and refuses to run under the Lua
# config manager ("keyword can't work with non-legacy parsers. Use eval."), so
# the mode is applied through the same hl.monitor() call the config uses.
#
# Skipped entirely when the client gave no mode: stream.lua's monitor rule has
# already given the output a size, and writing a made-up mode over it would
# only make the wrong one look deliberate.
if [ -n "$video_mode" ]; then
    hyprctl_logged eval "hl.monitor({ output = \"$SUNSHINE_MONITOR\", mode = \"$video_mode\", position = \"auto\", scale = 1 })"
fi

# Order matters. Focus first, then switch: a workspace that holds no windows
# does not exist yet, so moving it before it is created just prints "Workspace
# not found". Switching to it while the virtual output has focus creates it
# there, and the `workspace = 11, monitor:sunshine` rule in hyprland.conf pins
# it. The move afterwards is the belt-and-braces case where workspace 11 did
# already exist on a physical monitor from an earlier stream.
# Under Lua, `hyprctl dispatch` is shorthand for hl.dispatch(...) and the bare
# `focusmonitor sunshine` form is a Lua syntax error, not a dispatcher.
hyprctl_logged dispatch "hl.dsp.focus({ monitor = \"$SUNSHINE_MONITOR\" })"
hyprctl_logged dispatch "hl.dsp.focus({ workspace = $SUNSHINE_WORKSPACE })"
hyprctl_logged dispatch "hl.dsp.workspace.move({ workspace = $SUNSHINE_WORKSPACE, monitor = \"$SUNSHINE_MONITOR\" })"

# Record where things actually landed, not just that the dispatches returned 0.
hook_log "post-setup: $(hyprctl -j monitors 2>/dev/null | jq -c '[.[] | {name, focused, ws: .activeWorkspace.id}]' 2>/dev/null || echo 'query failed')"

# Make the virtual output X11's primary, so a game asking "how big is the
# display" gets 1280x800 rather than DP-3's 1920x1080 and renders to the size it
# will actually be shown at. Runs after the poll loop above because xrandr
# rejects an output that does not exist yet ("output sunshine not found").
#
# Strictly scoped to the stream: stream-end.sh puts it back, so local play on
# DP-3 and DP-1 never sees this. Best-effort -- a missing xrandr or a compositor
# that ignores RRSetOutputPrimary must not fail the stream.
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

# Nothing starts a fullscreen listener any more. Deciding *where* windows land
# is all this hook does; making the stream show one window rather than a dwindle
# split of Steam beside the game is hypr/stream.lua's job, handled in-process by
# a window rule plus window.open/window.close handlers. That replaced a Python
# daemon that parsed Hyprland's socket2 event stream from outside.
