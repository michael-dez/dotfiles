#!/usr/bin/env bash
# bcpc -- put the stream into game or desktop behaviour.
#
# Usage: stream-mode.sh game|desktop
#
# Two clients stream from this host, and they want opposite things from
# workspace 11:
#
#   game     the Steam Deck, through the "Steam Big Picture" app. One window,
#            fullscreen, pointer confined -- a dedicated game display.
#   desktop  BCLT, through Moonlight's "Desktop" app instead of RDP. An
#            ordinary tiling workspace, because a remote desktop that
#            fullscreens every terminal you open is not one.
#
# Called from two places, and both are deliberate:
#
#   stream-start.sh   reads SUNSHINE_APP_NAME and calls this BEFORE creating
#                     the headless output, so hypr/stream.lua's monitor.added
#                     handler already knows which mode it is coming up in.
#   apps.json         the "Desktop" app's own prep-cmd calls it again. That is
#                     not redundant: Sunshine's per-app environment is the only
#                     documented carrier of SUNSHINE_APP_NAME, and if it turns
#                     out not to reach a *global* prep command on this build,
#                     this second call is what still gets desktop mode right.
#                     Both calls are idempotent, so the overlap costs nothing.
#
# Best-effort like every other hook here: a stream must never fail because a
# window rule would not flip.

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

# Anything that is not "desktop" is game. An unset or misspelled app name then
# lands on the behaviour this host has always had, rather than on a half
# configured desktop -- the same defaulting stream.lua's set_mode() applies on
# the compositor side.
mode="game"
[ "${1:-}" = "desktop" ] && mode="desktop"

# Written before the eval, so that a `hyprctl reload` racing this call reads the
# mode we are moving to rather than the one we are leaving.
printf '%s\n' "$mode" > "$SUNSHINE_SESSION_MODE" 2>/dev/null || true

# `hyprctl eval` runs in the same Lua state the config was loaded into, so
# require()'s cache is the whole interface between this script and stream.lua --
# no socket, no daemon, no generated config file to re-read. If stream.lua
# failed to load, package.loaded.stream is nil and this call errors, which is
# exactly the signal wanted: the log then says the compositor side is not there
# rather than silently streaming with the wrong rules.
out=$(hyprctl eval "package.loaded.stream.set_mode(\"$mode\")" 2>&1) || true
hook_log "set_mode($mode) -> ${out:-no output}"

# Audio is the other half of desktop mode, and it is not cosmetic: Sunshine
# moves the system default sink to a sink of its own for the duration of every
# stream (observed in sunshine.log as "Setting default sink to:
# [sink-sunshine-stereo]"), while sunshine.conf captures "sunshine-stream".
# Those are two different sinks, so anything launched from a desktop stream
# plays into one nobody is recording. Game streams never noticed, because
# apps.json pins the app it launches with PULSE_SINK.
"$(dirname "$(readlink -f "$0")")/desktop-audio.sh" \
    "$([ "$mode" = "desktop" ] && echo on || echo off)"
