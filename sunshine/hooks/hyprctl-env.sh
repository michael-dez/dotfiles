# bcpc -- shared helper for the Sunshine stream hooks. Sourced, never executed.
#
# Sunshine runs the hooks from its systemd user service, which picked up
# HYPRLAND_INSTANCE_SIGNATURE from the environment import Hyprland does at
# startup. That import happens exactly once. Restart the compositor without
# restarting the service and the variable still names the dead instance, so
# every hyprctl call would target a socket that no longer exists -- silently,
# because hyprctl exits non-zero without saying why. Re-derive the signature
# from the runtime directory whenever the one we were handed is stale.
#
# Sourcing this exits the caller with status 0 if no live instance is found.
# A missing compositor must never fail a stream: the hooks are best-effort
# window management, not a precondition for streaming.

# --- logging --------------------------------------------------------------
# Sunshine discards hook output entirely. Its user unit sets no StandardOutput
# or StandardError, its journal stays empty, and nothing the hooks print reaches
# sunshine.log. That left every question about these scripts -- did they run, how
# far did they get, did they bail -- answerable only by inference from side
# effects like "the headless output exists, so line 29 must have run".
#
# XDG_STATE_HOME rather than XDG_RUNTIME_DIR, unlike the per-stream state at the
# bottom of this file: a post-mortem is worth most when it survives the reboot
# that followed the bug.
SUNSHINE_HOOK_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/sunshine-hooks.log"
mkdir -p "$(dirname "$SUNSHINE_HOOK_LOG")" 2>/dev/null

# $0 is the *sourcing* script, which is what we want to attribute lines to.
hook_log() {
    printf '%s [%s] %s\n' "$(date +%FT%T)" "${0##*/}" "$*" \
        >> "$SUNSHINE_HOOK_LOG" 2>/dev/null || true
}

# These run on every connect and disconnect, so cap the file rather than letting
# it grow for the life of the machine.
if [ -f "$SUNSHINE_HOOK_LOG" ] &&
    [ "$(wc -l < "$SUNSHINE_HOOK_LOG" 2>/dev/null || echo 0)" -gt 2000 ]; then
    if tail -n 1000 "$SUNSHINE_HOOK_LOG" > "$SUNSHINE_HOOK_LOG.tmp" 2>/dev/null; then
        mv "$SUNSHINE_HOOK_LOG.tmp" "$SUNSHINE_HOOK_LOG" 2>/dev/null || true
    fi
fi

# Set in the sourced file so all four hooks get it from one place. This is the
# piece that makes a mid-script abort visible: stream-start.sh runs under
# `set -euo pipefail`, so a single failed hyprctl call ends it silently.
trap 'hook_log "exit $?"' EXIT

hook_log "start"

hypr_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"

hypr_socket_live() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] &&
        [ -S "$hypr_runtime/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]
}

if ! hypr_socket_live; then
    hook_log "HYPRLAND_INSTANCE_SIGNATURE stale or unset (was '${HYPRLAND_INSTANCE_SIGNATURE:-}'), re-deriving"
    # Newest instance directory wins; -t sorts by mtime, newest first.
    for candidate in $(ls -1t "$hypr_runtime" 2>/dev/null); do
        if [ -S "$hypr_runtime/$candidate/.socket.sock" ]; then
            HYPRLAND_INSTANCE_SIGNATURE="$candidate"
            export HYPRLAND_INSTANCE_SIGNATURE
            hook_log "re-derived signature: $candidate"
            break
        fi
    done
fi

if ! hypr_socket_live; then
    # The one failure that used to leave no trace at all. Everything downstream
    # is skipped from here, and from outside that is indistinguishable from a
    # clean run, which is exactly why it is logged loudly.
    hook_log "BAIL: no live Hyprland instance under $hypr_runtime, skipping hook entirely"
    echo "sunshine hook: no live Hyprland instance under $hypr_runtime, skipping" >&2
    exit 0
fi

# The virtual output's name. Fixed on purpose: Hyprland's automatic naming
# counts up (HEADLESS-2, HEADLESS-3, ...) on every create, so a generated name
# would drift out of sync with output_name in sunshine.conf after the first
# disconnect. A custom name is stable for the life of the config.
SUNSHINE_MONITOR=sunshine

# Workspace reserved for the stream; bound to the virtual output in
# hypr/hyprland.conf.
SUNSHINE_WORKSPACE=11

# The XWayland display, for the primary-output flip in stream-start.sh.
#
# Derived rather than inherited for the same reason the instance signature is:
# Sunshine's systemd unit may hold a stale DISPLAY or none at all. Xwayland
# announces its display number as its own first argument, which is the one
# source that cannot go stale while the server is running.
#
# Games are X11 clients (Steam and every Proton title run under XWayland), and
# they ask the X server how big the display is. With no output marked primary
# they get the first one -- a physical monitor -- and render at its size
# regardless of which output their window is actually on.
# `pgrep -a` prints "PID COMMAND ARGS...", so the display is not at a fixed
# field index -- pick the argument that actually looks like one.
SUNSHINE_XDISPLAY=$(pgrep -a -x Xwayland 2>/dev/null |
    awk '{for (i = 1; i <= NF; i++) if ($i ~ /^:[0-9]+$/) { print $i; exit }}')

# Whatever was primary before the stream took over, so it can be handed back.
SUNSHINE_PREV_PRIMARY="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-prev-primary"

# Where stream-start.sh records the monitor that had focus when the stream
# began, so stream-end.sh can restore it. Runtime dir, not the config dir: this
# is per-boot state and should not outlive the session.
SUNSHINE_PREV_FOCUS="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-prev-focus"

