#!/usr/bin/env bash
# bcpc -- bring up Steam Big Picture on the stream workspace. Best-effort; never exercised against a real Steam
# as of the logging work. Why: docs/streaming.md#launch-bigpicturesh

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

steam_running() { pgrep -x steam >/dev/null 2>&1; }

bigpicture_up() {
    hyprctl -j clients 2>/dev/null |
        jq -e 'any(.[]; (.class|ascii_downcase|test("steam"))
                        and (.title|ascii_downcase|test("big picture")))' \
        >/dev/null 2>&1
}

steam_windows() {
    hyprctl -j clients 2>/dev/null |
        jq -c '[.[] | select(.class|ascii_downcase|test("steam"))
                    | {class, title, ws: .workspace.id}]' 2>/dev/null ||
        echo 'query failed'
}

if steam_running; then
    hook_log "steam already running"
else
    hook_log "steam not running, launching"
    setsid steam >/dev/null 2>&1 &
    waited=0
    for _ in $(seq 60); do
        steam_running && break
        waited=$((waited + 1))
        sleep 0.5
    done
    if steam_running; then
        hook_log "steam came up after $((waited * 5 / 10))s"
    else
        hook_log "BAIL-ish: steam never appeared after 30s, continuing anyway"
    fi
fi

sleep 2

for attempt in 1 2 3; do
    hook_log "attempt $attempt: dispatching steam://open/bigpicture"
    setsid steam steam://open/bigpicture >/dev/null 2>&1 &
    for _ in $(seq 20); do
        if bigpicture_up; then
            hook_log "SUCCESS: big picture window up on attempt $attempt; steam windows: $(steam_windows)"
            exit 0
        fi
        sleep 0.5
    done
    hook_log "attempt $attempt failed after 10s; steam windows now: $(steam_windows)"
    echo "launch-bigpicture: no Steam window on workspace $SUNSHINE_WORKSPACE after attempt $attempt" >&2
done

hook_log "GAVE UP after 3 attempts; exiting 0 so the desktop stream survives"
exit 0
