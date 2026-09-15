#!/usr/bin/env bash
# bcpc -- point the system default sink at the sink Sunshine actually captures,
# for the duration of a desktop stream.
#
# Usage: desktop-audio.sh on|off      (called only by stream-mode.sh)
#
# --- why this is needed ---------------------------------------------------
#
# Sunshine moves the system default sink to one of its own null sinks on every
# stream, whatever the config says. From sunshine.log, on a stream that never
# asked for it:
#
#     Info: config: 'audio_sink' = sunshine-stream
#     Info: Setting default sink to: [sink-sunshine-stereo]
#     Info: Found default monitor by name: sunshine-stream.monitor
#
# Two different sinks: it captures sunshine-stream and makes sink-sunshine-stereo
# the default. Anything that follows the default -- which is everything launched
# from a desktop session -- therefore plays into a sink nobody is recording, and
# is heard neither on the client nor at the desk.
#
# Game streams never hit this because apps.json launches the app with
# PULSE_SINK=sunshine-stream, pinning it past the default. A desktop stream has
# no such app: Sunshine launches nothing, and every window is opened later by
# Hyprland, which knows nothing about any of this.
#
# `virtual_sink` is not the fix, despite reading like it. This build gates that
# option to Windows -- in /usr/share/sunshine/web the input lives inside the
# PlatformLayout "windows" slot -- so on Linux it is not even rendered, let
# alone honoured.
#
# --- why it polls ---------------------------------------------------------
#
# Sunshine sets its default AFTER the prep commands return: prep ran at
# :18.0 and the sink moved at :18.970 in the log above. Setting the default
# from the prep command itself would simply be overwritten a second later. So
# this waits for Sunshine's move and then takes it back, in a detached child so
# the prep command returns immediately and the stream is never delayed.

set -u

ACTION="${1:-off}"

# Deliberately not sourcing hyprctl-env.sh, for the same reason the ollama
# hooks do not: that file exits the caller when no Hyprland instance is live,
# and audio routing has nothing to do with the compositor being up.
AUDIO_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$AUDIO_HOOK_LOG")" 2>/dev/null

hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$AUDIO_HOOK_LOG" 2>/dev/null || true
}

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# The sink Sunshine captures; pipewire/sunshine-sink.conf creates it.
CAPTURED_SINK="sunshine-stream"
# What the desk was using before the stream, so it can be handed back.
PREV_SINK="$RUNTIME/sunshine-prev-default-sink"
# stream-mode.sh's record of which mode is live. The poller re-reads it rather
# than trusting the mode it was started in: a stream that ends and is replaced
# by a game stream inside the poll window must not have its default sink
# yanked onto the capture sink by a child left over from the previous session.
SESSION_MODE="$RUNTIME/sunshine-session-mode"

sink_exists() {
    pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -qx "$1"
}

case "$ACTION" in
on)
    if ! sink_exists "$CAPTURED_SINK"; then
        hook_log "BAIL: sink '$CAPTURED_SINK' does not exist -- is pipewire/sunshine-sink.conf linked?"
        exit 0
    fi

    current=$(pactl get-default-sink 2>/dev/null)

    # Only record a sink that is actually the desk's. Recording one of
    # Sunshine's own -- which is what a reconnect inside the same stream would
    # find -- would make "restore" mean "leave it broken".
    case "$current" in
        sink-sunshine-*|"$CAPTURED_SINK"|"")
            hook_log "not recording previous default ('$current' is not a desk sink)"
            ;;
        *)
            printf '%s\n' "$current" > "$PREV_SINK" 2>/dev/null || true
            hook_log "previous default sink recorded: $current"
            ;;
    esac

    # Detached, with every descriptor closed: Sunshine waits for a prep command
    # to exit, and a child still holding stdout is a child it waits for too.
    setsid bash -c '
        captured="$1"; session_mode="$2"; log="$3"
        say() { printf "%s [desktop-audio.sh] %s\n" "$(date +%FT%T)" "$*" >> "$log" 2>/dev/null || true; }

        # Sunshine moved the default ~1s after the prep command returned. 15s of
        # polling is a wide margin around that, and the loop exits the moment it
        # sees the move rather than sleeping a fixed amount.
        waited=0
        for _ in $(seq 30); do
            case "$(pactl get-default-sink 2>/dev/null)" in
                sink-sunshine-*) break ;;
            esac
            waited=$((waited + 1))
            sleep 0.5
        done

        # Still a desktop stream? A game stream that started in the meantime
        # owns the default sink, and taking it now would break its audio.
        if [ "$(cat "$session_mode" 2>/dev/null)" != "desktop" ]; then
            say "session is no longer desktop, leaving the default sink alone"
            exit 0
        fi

        if pactl set-default-sink "$captured" 2>/dev/null; then
            say "default sink -> $captured after $((waited * 5 / 10))s (now: $(pactl get-default-sink 2>/dev/null))"
        else
            say "FAILED to set default sink to $captured"
        fi
    ' _ "$CAPTURED_SINK" "$SESSION_MODE" "$AUDIO_HOOK_LOG" </dev/null >/dev/null 2>&1 &

    hook_log "desktop audio handoff armed (waiting for Sunshine to move the default sink)"
    ;;

off)
    # Sunshine restores the default it saved before its own move, which is the
    # desk's sink -- so on a clean disconnect there is usually nothing to do
    # here. This is the backstop for the case that made stream-end.sh exist at
    # all: Sunshine dying, or a client vanishing without saying goodbye, which
    # would otherwise leave the desk silently playing into the capture sink.
    current=$(pactl get-default-sink 2>/dev/null)
    prev=$(cat "$PREV_SINK" 2>/dev/null)

    if [ "$current" = "$CAPTURED_SINK" ] && [ -n "$prev" ] && sink_exists "$prev"; then
        if pactl set-default-sink "$prev" 2>/dev/null; then
            hook_log "default sink restored to $prev"
        else
            hook_log "FAILED to restore default sink to $prev"
        fi
    else
        hook_log "no restore needed (default is '$current', recorded '${prev:-none}')"
    fi

    rm -f "$PREV_SINK"
    ;;

*)
    hook_log "unknown action '$ACTION' (expected on|off)"
    ;;
esac

exit 0
