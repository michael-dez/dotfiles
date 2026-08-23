#!/usr/bin/env bash
# bcpc -- bring up Steam Big Picture on the stream workspace.
#
# Replaces a bare `setsid steam steam://open/bigpicture` in apps.json, which
# fired the instant the prep-cmd returned and so raced Steam's own startup: on a
# cold connect Big Picture never appeared, while a reconnect worked because
# Steam was warm by then.
#
# Best-effort throughout. If this gives up, the client still has a working
# desktop stream -- that is a better outcome than failing the launch.
#
# NOTE: as of the logging work this script had never executed once -- every
# Sunshine session on record launched the "Desktop" app instead, so none of the
# polling below has ever been exercised against a real Steam. It is instrumented
# more heavily than the other hooks for that reason: the first real run is also
# its first test, and every `exit 0` here is indistinguishable from success
# without a log line saying which one fired.

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

steam_running() { pgrep -x steam >/dev/null 2>&1; }

# Proof the URL actually did something; the steam:// handler exits 0 whether or
# not a window ever appeared.
#
# Deliberately not checking *which* workspace: Steam maps onto whatever has
# focus, and moving it to the stream workspace belongs to hypr/stream.lua's
# capture rule. Tying the two together here would just make this poll a
# condition it cannot affect.
bigpicture_up() {
    hyprctl -j clients 2>/dev/null |
        jq -e 'any(.[]; (.class|ascii_downcase|test("steam"))
                        and (.title|ascii_downcase|test("big picture")))' \
        >/dev/null 2>&1
}

# What Steam-ish windows actually exist, for when the match above fails. The
# whole point of failure here is that the class or title was not what was
# expected, so the log has to carry the real values rather than just "no match".
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
    # Steam forks through a bootstrapper and re-execs itself, so wait for the
    # process rather than assuming the launch took.
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

# Give Steam a moment past process start to register its steam:// handler --
# it accepts the URL before it can act on it.
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

# Reached only when all three attempts failed. Still exit 0 -- the desktop
# stream is a better outcome than a failed launch -- but say so, because this
# used to be silent and looked exactly like the success path above.
hook_log "GAVE UP after 3 attempts; exiting 0 so the desktop stream survives"
exit 0
