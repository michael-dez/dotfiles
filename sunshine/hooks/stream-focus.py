#!/usr/bin/env python3
"""Fullscreen whatever opens on the stream workspace, for as long as a client is connected.

Started by stream-start.sh, killed by stream-end.sh.

Why a listener rather than a window rule: Hyprland 0.56 can express this as
`windowrule = fullscreen true, match:workspace 11`, and that rule parses without
error -- but it never applies, neither at window-map time nor on reload against a
window already sitting on the workspace. `match:class` works, but matching by
class would mean maintaining a list of every game's window class.

The listener also catches the case that actually broke: Steam is launched by
Sunshine, and Steam spawns the *game* as a separate window later. Nothing
attached to the command Sunshine ran can see that child window; an openwindow
event can.

Focus is left on the new window on purpose. Host and stream share one Hyprland
seat, so the streamed game only receives input while it holds focus -- restoring
focus to the desk would send the client's keystrokes to a desktop window.
"""

import json
import os
import socket
import subprocess
import sys
import time

WORKSPACE = os.environ.get("SUNSHINE_WORKSPACE", "11")

# Window classes to pull onto the stream workspace if they open anywhere else.
#
# Steam maps its windows onto whatever workspace holds focus at that moment, and
# focus drifts -- the desk mouse moves, or a cold Steam start takes long enough
# that the prep-cmd's focus call is ancient history. Big Picture landing on the
# desktop instead of the stream is exactly that. Placement cannot be pinned at
# launch either: the `steam://` URL is handled by the already-running Steam
# process, so the window is not a child of anything we spawn.
#
# Safe here because Steam is used at the desk or by the stream, never both at
# once, and this listener only runs while a client is connected.
CAPTURE_CLASSES = [
    c.strip().lower()
    for c in os.environ.get("SUNSHINE_CAPTURE_CLASSES", "steam").split(",")
    if c.strip()
]


def hyprctl(*args):
    """Fire a hyprctl command; never let a failure kill the listener."""
    try:
        return subprocess.run(("hyprctl",) + args, capture_output=True, timeout=5)
    except (subprocess.SubprocessError, OSError) as e:
        print(f"stream-focus: hyprctl {args} failed: {e}", file=sys.stderr)
        return None


def clients():
    """Every window Hyprland knows about, or [] if the query failed."""
    r = hyprctl("-j", "clients")
    if r is None or r.returncode != 0:
        return []
    try:
        return json.loads(r.stdout)
    except (json.JSONDecodeError, TypeError):
        return []


def stream_clients():
    """Windows currently on the stream workspace."""
    return [c for c in clients() if str(c.get("workspace", {}).get("id")) == WORKSPACE]


def go_fullscreen(window):
    """Put one window into real fullscreen, telling the client about it.

    Both axes matter. `internal` is how Hyprland lays the window out; `client`
    is what the application is told. Setting only the internal one resizes the
    frame to the output while the game keeps rendering at its old windowed
    size, and what reaches the encoder is the top-left crop of a larger image.

    Neither `fullscreen` nor `fullscreenstate` is an idempotent setter -- asking
    for the state a window is already in toggles it back off -- so check before
    acting. Games that map already-fullscreen are common, and knocking one back
    to a tile is exactly the bug this function exists to avoid.
    """
    if window.get("fullscreen") == 2 and window.get("fullscreenClient") == 2:
        return

    address = window.get("address")
    if not address:
        return

    # focuswindow first: the fullscreen dispatchers act on the active window
    # and take no window argument.
    hyprctl("dispatch", "focuswindow", f"address:{address}")
    # 2 = real fullscreen on both axes. 1 would be maximize, which leaves the
    # bar's reserved area carved out of the stream.
    hyprctl("dispatch", "fullscreenstate", "2", "2")


def main():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not sig:
        print("stream-focus: HYPRLAND_INSTANCE_SIGNATURE unset", file=sys.stderr)
        return 0

    path = f"{runtime}/hypr/{sig}/.socket2.sock"
    try:
        sock = socket.socket(socket.AF_UNIX)
        sock.connect(path)
    except OSError as e:
        print(f"stream-focus: cannot connect to {path}: {e}", file=sys.stderr)
        return 0

    buf = ""
    with sock:
        while True:
            try:
                chunk = sock.recv(4096)
            except OSError:
                break
            if not chunk:
                break  # compositor went away

            buf += chunk.decode(errors="replace")
            # Events are newline-delimited, but a read can split one in half.
            *lines, buf = buf.split("\n")

            for line in lines:
                if line.startswith("openwindow>>"):
                    # openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE -- the title may
                    # contain commas, so split only the three fields ahead of it.
                    fields = line[len("openwindow>>"):].split(",", 3)
                    if len(fields) < 3:
                        continue

                    address = f"0x{fields[0]}"
                    on_stream = fields[1] == WORKSPACE
                    klass = fields[2].lower()

                    if not on_stream:
                        if not any(c in klass for c in CAPTURE_CLASSES):
                            continue
                        hyprctl(
                            "dispatch",
                            "movetoworkspacesilent",
                            f"{WORKSPACE},address:{address}",
                        )

                    # Let the window settle: some games map and then request
                    # fullscreen themselves a moment later, and acting first
                    # would race that.
                    time.sleep(0.4)

                    for c in stream_clients():
                        if c.get("address") == address:
                            go_fullscreen(c)
                            break

                elif line.startswith("closewindow>>"):
                    # Hyprland allows one fullscreen window per workspace, so
                    # the game going fullscreen dropped Big Picture back to a
                    # tile. When the game exits, nothing restores it -- that is
                    # what this branch is for.
                    #
                    # The event carries only an address, with no workspace, so
                    # there is nothing to match on; just re-inspect the stream
                    # workspace and fix it up if it needs it.
                    time.sleep(0.4)

                    remaining = stream_clients()
                    if not remaining:
                        continue
                    if any(c.get("fullscreen") == 2 for c in remaining):
                        continue  # something already covers the output

                    # Lowest focusHistoryID is the most recently focused window,
                    # which is the one the user was looking at before whatever
                    # was on top went away.
                    remaining.sort(key=lambda c: c.get("focusHistoryID", 1 << 30))
                    go_fullscreen(remaining[0])

    return 0


if __name__ == "__main__":
    sys.exit(main())
