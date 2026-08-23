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

set -u

# shellcheck source=hyprctl-env.sh
. "$(dirname "$(readlink -f "$0")")/hyprctl-env.sh"

steam_running() { pgrep -x steam >/dev/null 2>&1; }

# Proof the URL actually did something; the steam:// handler exits 0 whether or
# not a window ever appears.
#
# Deliberately not checking *which* workspace: Steam maps onto whatever has
# focus, and moving it to the stream workspace is stream-focus.py's job. Tying
# the two together here would just make this poll a condition it cannot affect.
bigpicture_up() {
    hyprctl -j clients 2>/dev/null |
        jq -e 'any(.[]; (.class|ascii_downcase|test("steam"))
                        and (.title|ascii_downcase|test("big picture")))' \
        >/dev/null 2>&1
}

if ! steam_running; then
    setsid steam >/dev/null 2>&1 &
    # Steam forks through a bootstrapper and re-execs itself, so wait for the
    # process rather than assuming the launch took.
    for _ in $(seq 60); do
        steam_running && break
        sleep 0.5
    done
fi

# Give Steam a moment past process start to register its steam:// handler --
# it accepts the URL before it can act on it.
sleep 2

for attempt in 1 2 3; do
    setsid steam steam://open/bigpicture >/dev/null 2>&1 &
    for _ in $(seq 20); do
        bigpicture_up && exit 0
        sleep 0.5
    done
    echo "launch-bigpicture: no Steam window on workspace $SUNSHINE_WORKSPACE after attempt $attempt" >&2
done

exit 0
