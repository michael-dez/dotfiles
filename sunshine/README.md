# Sunshine streaming setup

Streams a headless Hyprland output over Moonlight, to two clients that want very
different things from it: a Steam Deck playing games, and BCLT (the laptop)
using it as a remote desktop in place of RDP. Hyprland-side configuration lives
in `../hypr/stream.lua`; this directory holds Sunshine's own config and the
hooks it runs.

## How a stream works

1. Moonlight connects. Sunshine runs `global_prep_cmd` "do" → `hooks/stream-start.sh`:
   reads `SUNSHINE_APP_NAME` to pick the session mode, creates a headless output
   named `sunshine`, sizes it to the client's negotiated mode, parks workspace 11
   on it, focuses it, and makes it XWayland's primary output.
2. Sunshine launches the selected app. `Steam Big Picture` runs
   `hooks/launch-bigpicture.sh`; `Desktop` launches nothing but runs
   `hooks/stream-mode.sh desktop` as its own prep command.
3. `hypr/stream.lua` applies the rules for that mode, for as long as the
   `sunshine` output exists.
4. On disconnect, "undo" → `hooks/stream-end.sh` reverses all of it.

## Two session modes

Workspace 11 is a game display or a desktop, never both, and the app tile you
tap is what decides:

| | `game` (Steam Big Picture) | `desktop` (Desktop) |
| --- | --- | --- |
| Windows on workspace 11 | forced fullscreen, one at a time | tiled normally |
| Pointer | confined to the window | free |
| Borders and gaps | off | on |
| Stray Steam windows | pulled onto the stream | left alone |
| Default audio sink | untouched (the app is pinned with `PULSE_SINK`) | moved to the captured sink |

The game rules are not a harmless extra in a desktop session — they would
fullscreen every terminal you opened and trap the cursor inside it — which is
why the mode exists at all rather than one config serving both.

The switch is `hooks/stream-mode.sh game|desktop`. It writes
`$XDG_RUNTIME_DIR/sunshine-session-mode` and calls into the compositor with:

```sh
hyprctl eval 'package.loaded.stream.set_mode("desktop")'
```

That reach works because `hyprctl eval` runs in the same Lua state the config
was loaded into, so `require`'s cache is the whole interface between the shell
hooks and `stream.lua` — no socket, no daemon, no generated file. Anything other
than `desktop` means game, so an app name that never arrives lands on the
behaviour this host has always had.

It is called twice, deliberately. `stream-start.sh` calls it from the *global*
prep command, early enough that the output comes up in the right mode; the
`Desktop` app calls it again from its own prep command, which is the path that
still works if `SUNSHINE_APP_NAME` turns out not to reach a global prep command
on some future build. Both calls are idempotent.

### Reaching your other workspaces from a desktop stream

`MOD5+CTRL+<number>` brings workspace N *to* the stream. The plain
`MOD5+<number>` cannot do this and never will: focusing a workspace that lives
on another monitor moves focus to that monitor, so the client would keep showing
workspace 11 while every keystroke landed in a window on the desk. Off-stream
the CTRL binding degrades to a plain focus.

`hooks/stream-end.sh` moves every workspace off the virtual output before
removing it, not just workspace 11, precisely because of this.

## Resolution follows the client

There is no host-side resolution. `stream-start.sh` builds the output from
`SUNSHINE_CLIENT_WIDTH`/`HEIGHT`/`FPS`, which is what Moonlight negotiated — so
a Steam Deck in a dock streams at its television's mode, and the same Deck
undocked streams at the panel's, with nothing to change here between them.

Two things used to get in the way, and both are fixed rather than worked around:

- `stream.lua` hardcoded `1280x800@90` for the `sunshine` output. Monitor rules
  are re-applied by `hyprctl reload` — and Hyprland auto-reloads when a config
  file is edited — so a reload mid-stream snapped a 1080p stream back to Deck
  size. It now reads `$XDG_RUNTIME_DIR/sunshine-video-mode`, which
  `stream-start.sh` writes; failing that it re-applies the mode the output is
  already running at, so a reload cannot resize a live stream even with no state
  file; and only with no stream at all does it fall back to `preferred`. Never
  to a fixed resolution.
- `stream-start.sh` fell back to `1280x800@90` when the client mode was missing
  from the environment. It now sets no mode at all in that case and says so
  loudly in the hook log, because a wrong size on an output nobody can see is
  invisible from the host.

If a client streams at the wrong size, the hook log answers it in one line:

```sh
grep "client mode" ~/.local/state/sunshine-hooks.log
```

That prints both the mode used and the raw environment it came from. If the
environment says 1280x800 while the television is 1080p, the negotiation is the
client's doing and the fix is in Moonlight's settings on the client, not here.

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

`stream-mode.sh` and `desktop-audio.sh` log to the same file, so one `tail` shows
the mode a stream came up in, the app name it was derived from, and whether the
audio handoff took.

### Nothing launched from a desktop stream can be heard

Sunshine moves the system default sink to a sink of its own on every stream,
whatever `audio_sink` says — `Setting default sink to: [sink-sunshine-stereo]`
in `sunshine.log`, while this config captures `sunshine-stream`. Two different
sinks, so anything following the default plays where nobody is recording. Game
streams never noticed because `apps.json` pins the launched app with
`PULSE_SINK`; a desktop stream has no such app. `hooks/desktop-audio.sh` waits
for Sunshine's move and takes the default back to the captured sink, then hands
it to the desk on disconnect. Check it with:

```sh
pactl get-default-sink                                   # sunshine-stream while streaming
grep desktop-audio ~/.local/state/sunshine-hooks.log
```

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

Note that those numbers are a Deck panel, and a launch option cannot know which
client is connected. A title pinned this way streams at 1280x800 to a docked
Deck as well, letterboxed on the television — so give gamescope the size you
actually stream at most often, or drop it for that title and rely on the three
mitigations above.

## Not linked into this repo

`sunshine_state.json` and `credentials/` hold the Web UI password hash and paired
client certificates. This repo is published; they stay local.
