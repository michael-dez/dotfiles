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

hypr_runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"

hypr_socket_live() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] &&
        [ -S "$hypr_runtime/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]
}

if ! hypr_socket_live; then
    # Newest instance directory wins; -t sorts by mtime, newest first.
    for candidate in $(ls -1t "$hypr_runtime" 2>/dev/null); do
        if [ -S "$hypr_runtime/$candidate/.socket.sock" ]; then
            HYPRLAND_INSTANCE_SIGNATURE="$candidate"
            export HYPRLAND_INSTANCE_SIGNATURE
            break
        fi
    done
fi

if ! hypr_socket_live; then
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

# Where stream-start.sh records the monitor that had focus when the stream
# began, so stream-end.sh can restore it. Runtime dir, not the config dir: this
# is per-boot state and should not outlive the session.
SUNSHINE_PREV_FOCUS="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-prev-focus"

# PID file for the openwindow listener that stream-start.sh backgrounds and
# stream-end.sh reaps. Runtime dir for the same reason as the focus state above.
SUNSHINE_FOCUS_PID="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sunshine-focus.pid"
