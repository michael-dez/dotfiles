#!/usr/bin/env bash
# bcpc -- point the default sink at the sink Sunshine captures during a desktop stream.   Usage: desktop-audio.sh on|off
# Polls because Sunshine moves the default after prep returns. Why: docs/streaming.md#desktop-audiosh

set -u

ACTION="${1:-off}"

AUDIO_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$AUDIO_HOOK_LOG")" 2>/dev/null

hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$AUDIO_HOOK_LOG" 2>/dev/null || true
}

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CAPTURED_SINK="sunshine-stream"
PREV_SINK="$RUNTIME/sunshine-prev-default-sink"
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

    case "$current" in
        sink-sunshine-*|"$CAPTURED_SINK"|"")
            hook_log "not recording previous default ('$current' is not a desk sink)"
            ;;
        *)
            printf '%s\n' "$current" > "$PREV_SINK" 2>/dev/null || true
            hook_log "previous default sink recorded: $current"
            ;;
    esac

    setsid bash -c '
        captured="$1"; session_mode="$2"; log="$3"
        say() { printf "%s [desktop-audio.sh] %s\n" "$(date +%FT%T)" "$*" >> "$log" 2>/dev/null || true; }

        waited=0
        for _ in $(seq 30); do
            case "$(pactl get-default-sink 2>/dev/null)" in
                sink-sunshine-*) break ;;
            esac
            waited=$((waited + 1))
            sleep 0.5
        done

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
