# Sunshine streaming setup

Streams a headless Hyprland output to a Steam Deck over Moonlight. Hyprland-side
configuration lives in `../hypr/stream.lua`; this directory holds Sunshine's own
config and the hooks it runs.

## How a stream works

1. Moonlight connects. Sunshine runs `global_prep_cmd` "do" → `hooks/stream-start.sh`:
   creates a headless output named `sunshine`, sizes it to the client's
   negotiated mode, parks workspace 11 on it, focuses it, and makes it XWayland's
   primary output.
2. Sunshine launches the selected app. `Steam Big Picture` runs
   `hooks/launch-bigpicture.sh`; `Desktop` launches nothing.
3. `hypr/stream.lua` fullscreens whatever lands on workspace 11 and pulls stray
   Steam windows onto it, for as long as the `sunshine` output exists.
4. On disconnect, "undo" → `hooks/stream-end.sh` reverses all of it.

## Debugging: read the log first

The hooks log to `~/.local/state/sunshine-hooks.log`. This exists because
Sunshine discards hook output entirely — its systemd user unit sets no
`StandardOutput`/`StandardError`, its journal stays empty, and nothing the hooks
print reaches `sunshine.log`. Without the log, "did this hook run, and how far
did it get" is answerable only by guessing from side effects.

```sh
tail -f ~/.local/state/sunshine-hooks.log     # hooks
hyprctl rollinglog | grep stream.lua          # the Hyprland side
grep "Executing \[" ~/.config/sunshine/sunshine.log   # which app Moonlight asked for
```

That last one matters more than it looks. Moonlight caches the app list, and a
stale cache maps a tapped tile to the wrong app ID server-side — so the log line
is the only reliable statement of what actually launched. If it says `[Desktop]`
when you tapped Steam, re-pair the host before trusting anything else you see.

## hyprctl syntax changed with the Lua migration

Under the Lua config manager the legacy `hyprctl` forms are gone, and the failure
is quiet — `hyprctl keyword` returns rc=0 while doing nothing:

| Legacy (broken)                            | Lua                                                        |
| ------------------------------------------ | ---------------------------------------------------------- |
| `hyprctl keyword monitor NAME,MODE,...`     | `hyprctl eval 'hl.monitor({ output = ..., mode = ... })'`   |
| `hyprctl dispatch focusmonitor NAME`        | `hyprctl dispatch 'hl.dsp.focus({ monitor = "NAME" })'`     |
| `hyprctl dispatch workspace N`              | `hyprctl dispatch 'hl.dsp.focus({ workspace = N })'`        |
| `hyprctl dispatch moveworkspacetomonitor`   | `hyprctl dispatch 'hl.dsp.workspace.move({ ... })'`         |
| `hyprctl dispatch movetoworkspacesilent`    | `hl.dsp.window.move({ workspace = N, follow = false, ... })`|

`hyprctl output create|remove` and the `-j` info commands are unchanged.

## If a game streams cropped to the top-left

The frame shows the top-left corner of a larger image: the game rendered at one
size and is being displayed at another. Three mitigations are already in place,
in increasing order of bluntness — check them in this order.

1. **Confirm which app actually launched** (see above). The `Desktop` app leaves
   Steam on a physical monitor, so a game it spawns inherits that monitor's
   geometry rather than the stream's.
2. **`hypr/stream.lua`'s `stream-game` rule** suppresses `fullscreenoutput` and
   `x11configurerequest` and forces `sync_fullscreen`, matched on workspace 11.
3. **The XWayland primary flip** in `stream-start.sh` makes `sunshine` the output
   an X11 client gets when it asks how big the display is.

If a specific title still crops, give it gamescope in its Steam launch options —
gamescope hands the game a fixed virtual display and scales whatever it renders,
which makes the crop structurally impossible:

```
gamescope -W 1280 -H 800 -r 90 -f -- %command%
```

Deliberately per-game. Overwatch streams correctly without it and should not pay
the extra compositing hop.

## Not linked into this repo

`sunshine_state.json` and `credentials/` hold the Web UI password hash and paired
client certificates. This repo is published; they stay local.
