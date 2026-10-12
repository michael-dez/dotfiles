# Sunshine streaming (bcpc)

bcpc streams a headless Hyprland output over Moonlight to a Steam Deck (games)
and BCLT (remote desktop). The operational guide (how a stream works, the two
modes, debugging) is [`sunshine/README.md`](../sunshine/README.md); this file
holds the per-file rationale. Hyprland side: `hypr/stream.lua`. The ollama
hooks are in [llm.md](llm.md#stream-hooks).

## sunshine.conf

`sunshine/sunshine.conf` -> `~/.config/sunshine/sunshine.conf` (symlinked)

Sunshine's Web UI writes through the symlink, so changes land in `git status`
rather than drifting, but it rewrites the whole file and drops comments, so edit
the file directly. Read only at startup: `systemctl --user restart sunshine`.

**Known limitations, so they don't get "fixed" later.**

- **Keyboard and mouse are a shared seat.** Sunshine injects input through uinput
  as vendor `beef`, product `dead` ("Keyboard passthrough", "Mouse passthrough"),
  landing in the same Hyprland seat as the physical keyboard. Hyprland has one
  seat and one keyboard focus with no per-device routing, so typing at the desk
  mid-stream reaches the streamed game and vice versa. Only video, audio and
  app-launch focus are isolated. Separating input needs a second compositor
  session, which Hyprland can't host: it requests the DRM backend unconditionally
  and has no headless-only mode.
- **HDR is unavailable.** wlr-screencopy carries no HDR metadata, so with
  `capture = wlr`, `hevc_mode = 3` would advertise HDR without delivering it.

**capture / output_name.** `capture = wlr`, not the KMS default: KMS enumerates
DRM connectors and can't see a compositor-side headless output, which is exactly
what this streams. `output_name = sunshine` is the virtual output created on
connect by `hooks/stream-start.sh`, matched by name (Sunshine compares
`output_name` to each output's name before treating it as an index). Without it,
Sunshine uses `monitors[0]`, whichever display enumerates first.

**global_prep_cmd.** Two pairs, run in array order on connect and in reverse on
disconnect. ollama first so the GPU is handed over before the virtual output
exists and the app launches: `ollama.socket` is armed for the whole LAN-facing
lifetime, so a model can be loaded at any moment until the hook stops it. Its
resume therefore runs last on the way out. A prep cmd exiting non-zero aborts
the launch; both exit 0 unconditionally, so neither pair can cost a stream.
`stream-start.sh` also reads `SUNSHINE_APP_NAME` and picks game or desktop mode
before the output exists (see README).

**Video.**

- `encoder = nvenc` pinned rather than probed, so a driver update can't quietly
  demote the stream to software encoding.
- `nvenc_preset = 1` (P1) is the lowest-latency NVENC preset; handheld
  resolutions leave quality headroom and latency is worth spending on. Despite the
  docs filing `nvenc_*` under Windows, these three feed `config::video.nv_legacy`,
  which the Linux ffmpeg NVENC path reads too.
- `nvenc_spatial_aq = enabled` costs little at this resolution and helps dark
  scenes, where a flat quantizer wastes bits on noise and starves shadows.
- `min_threads = 4` (default 2): more threads for packet handling, which the host
  has to spare.
- Left at defaults on purpose: `fec_percentage` 20 (a wireless client needs the
  redundancy); `hevc_mode`/`av1_mode` 0 (let the client negotiate; modern
  handhelds decode both).

**Audio.** `audio_sink = sunshine-stream` captures our own null sink
([`pipewire/sunshine-sink.conf`](#pipewire-sink)) instead of the default output;
streamed apps are pointed at it via `PULSE_SINK` in `apps.json`.
`virtual_sink` is **unset** because on Linux it does nothing: this build renders
that input only inside the Web UI's "windows" platform slot
(`/usr/share/sunshine/web`). Setting it wouldn't help anyway, because Sunshine
moves the system default sink on its own on every stream:

```
Info: config: 'audio_sink' = sunshine-stream
Info: Setting default sink to: [sink-sunshine-stereo]
Info: Found default monitor by name: sunshine-stream.monitor
```

Two different sinks: it captures the named one and makes its own the default, so
anything following the default plays where nobody is listening for the length of
the stream. Game streams never noticed (`apps.json` pins the app with
`PULSE_SINK`); desktop streams launch everything from the compositor with no pin.
`hooks/desktop-audio.sh` repairs that, desktop streams only.

**Input.**

- `key_rightalt_to_key_win = disabled` must stay disabled: `hypr/bcpc.lua` sets
  `kb_options=lv3:ralt_switch`, making Right Alt the Hyprland `$mod` for every
  binding; remapping it to Super on the way in would break all of them from the
  client.
- `gamepad = x360`, pinned so the pad's identity is stable across reconnects and
  games don't re-detect a different controller mid-session. **x360, not ds5.**
  Sunshine backs DualSense emulation with a uhid device, which has a
  `/dev/hidraw` node; x360 is plain uinput evdev with none. Steam Input and
  Proton's winedevice both open a DualSense by hidraw, and with Steam Input forced
  on for a title they hold the same node at once (observed: steam and
  `winedevice.exe` each holding `/dev/hidraw15`), so HID reports go to whichever
  reader wins and the controls die. No hidraw node, nothing to contend over.
  Nothing lost: ds5 was chosen for motion and touchpad and the client reports
  neither. Sunshine says so on every connect ("Gamepad 0 is emulating a
  motion-capable controller, but the client gamepad does not have motion sensors
  active", likewise touchpad). If a client that reports motion ever streams here,
  reconsider ds5, but disable Steam Input per game rather than sharing hidraw.
- **Gamepad isolation is currently a no-op**: no physical controller on the host,
  so the client's virtual pad is the only one games see. If one is plugged in at
  the desk, hide it from streamed games by adding
  `SDL_GAMECONTROLLER_IGNORE_DEVICES=0xVID/0xPID` to the `env` block in
  `apps.json` (JSON takes no comments, hence this note).

## Pipewire sink

`pipewire/sunshine-sink.conf` -> `~/.config/pipewire/pipewire.conf.d/sunshine-sink.conf`

A null sink that exists only to be captured. Sunshine captures the monitor of
whatever sink `audio_sink` names; launching streamed apps with
`PULSE_SINK=sunshine-stream` keeps stream and desktop audio on separate paths
(client hears the game, desk keeps its headset, neither hears the other).
Sunshine can create null sinks itself, but its `virtual_sink` also calls
`pa_context_set_default_sink`, moving the *system* default onto the capture sink
and silencing the desktop. Owning the sink here avoids that. Static rather than
created on connect so its ID is stable across streams, which matters for anything
that remembers per-app routing.

`context.objects`, not `context.modules`: the adapter factory is already loaded
by the stock config, and asking again loads nothing. `audio.rate = 48000` matches
Sunshine's Opus encode so nothing resamples on the way out.

## OOMPolicy drop-in

`sunshine/systemd/oom.conf` ->
`~/.config/systemd/user/app-dev.lizardbyte.app.Sunshine.service.d/oom.conf`

When Sunshine starts Steam itself (the Big Picture app hook, as opposed to
attaching to a Steam already running on the desktop), everything Steam launches
inherits this unit's cgroup. systemd defaults `OOMPolicy` to `stop` for services,
so the kernel OOM-killing any one descendant stops the unit and takes Sunshine
and the whole Steam tree with it. `continue` is what systemd already applies to
scopes, which is why a desktop-started Steam survives the same event and loses
only the game.

## Hooks

Run by Sunshine from its systemd user service. Sunshine discards hook output
entirely (no `StandardOutput`/`StandardError`, empty journal, nothing in
`sunshine.log`), so the hooks log to `~/.local/state/sunshine-hooks.log`; see the
README for debugging recipes.

### hyprctl-env.sh

Sourced, never executed. Shared by the Hyprland hooks.

- **Stale signature.** The service gets `HYPRLAND_INSTANCE_SIGNATURE` from the
  environment import Hyprland does once at startup. Restart the compositor without
  restarting the service and the variable names the dead instance, so every
  `hyprctl` call targets a nonexistent socket, silently (it exits non-zero without
  saying why). It re-derives the signature from the runtime dir (newest instance
  with a live socket; `ls -t`) whenever the inherited one is stale.
- **Exits the caller with 0 if no live instance is found.** A missing compositor
  must never fail a stream; the hooks are best-effort window management. This is
  why the ollama and audio hooks do *not* source it.
- **Logging.** `XDG_STATE_HOME`, not `XDG_RUNTIME_DIR` like the per-stream state:
  a post-mortem is worth most when it survives the reboot that followed the bug.
  `hook_log` attributes lines to `$0`, the sourcing script. The log is capped
  (trimmed to 1000 lines past 2000) since hooks run on every connect/disconnect.
- **`trap ... EXIT`** logs the exit code, which makes a mid-script abort visible:
  `stream-start.sh` runs under `set -euo pipefail`, so one failed `hyprctl` ends it
  silently.
- **Fixed monitor name `sunshine`.** Hyprland's automatic naming counts up
  (`HEADLESS-2`, `-3`, ...) on every create, so a generated name would drift from
  `output_name` after the first disconnect. A custom name is stable.
- **Workspace 11** reserved for the stream, bound to the virtual output in
  `hypr/stream.lua`.
- **XWayland display** is derived from `pgrep -a -x Xwayland` rather than
  inherited, for the same staleness reason; Xwayland announces its display number
  as its own argument, the one source that can't go stale while it runs. `pgrep -a`
  prints `PID COMMAND ARGS...`, so the awk picks the argument that looks like
  `:N`. It's needed for the primary-output flip: games are X11 clients (Steam and
  every Proton title run under XWayland) asking the X server how big the display
  is, and with no output marked primary they get the first one, a physical
  monitor, and render at its size wherever their window is.
- **State files** in `XDG_RUNTIME_DIR` (per-boot, shouldn't outlive the session):
  `sunshine-prev-primary`, `sunshine-prev-focus`, plus the two `hypr/stream.lua`
  reads on load, `sunshine-video-mode` (`1920x1080@60`) and
  `sunshine-session-mode` (`game`|`desktop`). Defined here so the compositor and
  hook sides can't disagree about paths. They exist because `hyprctl reload`
  re-runs the Hyprland config from scratch and a mid-stream reload mustn't
  re-apply a hardcoded mode or revert a desktop session to game rules. Removed
  by `stream-end.sh`, so absence means no stream.

### stream-start.sh

`global_prep_cmd` "do"; undone by `stream-end.sh`. Creates a headless output sized
to the client, parks workspace 11 on it, focuses it. Sunshine runs it before
launching the app, so the app's window opens on the focused workspace, now the
virtual output; that ordering keeps the stream on the game without window rules
or class matching.

- **Session mode** from `SUNSHINE_APP_NAME`: `*[Dd]esktop*` is desktop, else game.
  Matched loosely so a later "Desktop (1080p)" tile doesn't silently fall to the
  game rules; defaults to game so a missing name lands on the host's long-standing
  behaviour. `stream-mode.sh` is called *before* the output exists because
  `stream.lua`'s `monitor.added` handler reads the mode and the workspace rules
  apply when the workspace lands on the output.
- **`hyprctl_logged`** wrapper: `hyprctl` reports failure only through exit
  status and prints nothing useful, and under `set -e` one failed call ends the
  script with no evidence of which. `|| rc=$?` keeps errexit from firing on the
  assignment so the failure is logged before it propagates.
- **No resolution fallback**, deliberately. The old one was a Deck OLED panel
  (1280x800), precisely the assumption that made a docked client stream at the
  wrong size, and a wrong size is invisible from the host because nobody can see
  that output. If the mode is missing the output stays at whatever Hyprland gives
  it and the hook says so loudly; `stream.lua`'s fallback chain (live mode, else
  `preferred`) covers it. Only fps keeps a fallback (60): it's the one field a mode
  string can't omit and is true of every display that isn't a handheld.
- **Focus is captured before the output is created**: creating a headless output
  moves focus onto it, so reading "the focused monitor" afterwards would record
  `sunshine` and leave `stream-end.sh` nothing useful to restore.
- **Creation is asynchronous**: the output appears a frame or two later and setting
  its mode before it exists is a no-op leaving the client at the default headless
  size, hence the 20x0.1s poll. If it never appears the hook bails (exit 0) and the
  stream falls back to a physical display.
- **Mode via `hyprctl eval hl.monitor(...)`**: `hyprctl keyword` is legacy-parser
  only and refuses under the Lua config manager ("keyword can't work with
  non-legacy parsers. Use eval."). Skipped when the client gave no mode: writing a
  made-up mode over `stream.lua`'s rule would only make the wrong one look
  deliberate.
- **Order matters: focus first, then switch.** A workspace holding no windows
  doesn't exist yet, so moving it first prints "Workspace not found". Switching to
  it while the virtual output has focus creates it there, and the workspace rule
  pins it. The explicit move afterwards is belt-and-braces for when workspace 11
  already existed on a physical monitor from an earlier stream. Under Lua,
  `hyprctl dispatch` is shorthand for `hl.dispatch(...)`; the bare
  `focusmonitor sunshine` form is a Lua syntax error.
- **X11 primary flip** makes the virtual output primary so a game asking for the
  display size gets the stream's size (1280x800), not DP-3's 1920x1080. Runs after
  the poll because xrandr rejects a nonexistent output. Scoped to the stream
  (`stream-end.sh` restores it), so local play on DP-3 and DP-1 never sees it.
  Best-effort.
- **No fullscreen listener** any more: deciding where windows land is all the hook
  does. Making the stream show one window rather than a dwindle split is
  `stream.lua`'s job via a window rule plus `window.open`/`window.close`
  handlers, replacing a Python daemon (`stream-focus.py`) that parsed Hyprland's
  socket2 event stream from outside.

### stream-end.sh

`global_prep_cmd` "undo". Runs on disconnect, including a client dying without
goodbye. Also bound to a keybind in `hypr/keybinds.lua` as a manual escape hatch
when a crashed stream never fires it.

- **Deliberately not `set -e`**: a failure partway would leave the virtual output
  alive with workspace 11 stranded on it, and since that output is invisible so is
  every window on it. Each step is best-effort so teardown always reaches
  `output remove`. Its `hyprctl_logged` therefore never propagates failure.
- **No listener to stop**: `stream.lua` keys off the headless output's existence,
  so removing it disarms the rules.
- **Restore target**: prefer the monitor that had focus at stream start, else the
  first non-`sunshine` monitor. Resolved, never hardcoded (connector names differ
  per machine and the layout changes often). Validated: the remembered monitor
  may have been unplugged, and must never be the output about to be removed.
- **Evacuate workspace 11 windows**: moving the workspace alone isn't enough,
  `keybinds.lua` binds 1-10 only, so anything left on 11 is unreachable by
  keyboard after the stream. Workspace 11 is an implementation detail of
  streaming and shouldn't hold applications between sessions.
- **Move *every* workspace off the virtual output**, not just 11: a desktop stream
  can pull any workspace over with `MOD5+CTRL+<number>` (`pull_workspace()` in
  `stream.lua`), so several may be sitting there. They need no evacuation since
  all are reachable by keybind once back on a real monitor. Hyprland would
  relocate them on its own, but not predictably to the monitor wanted.
- **No monitor left**: still remove the output (Hyprland handles having none) but
  skip the moves, which would only fail.
- **X11 primary** is handed back before the output goes away (an xrandr call can't
  name a nonexistent output); `--noprimary` if nothing was primary before, since
  picking a monitor arbitrarily would leave the desk in a state the user never
  chose.
- **`stream-mode.sh game`** runs at the end so window rules are only re-armed once
  nothing is left on the virtual output to catch them. Safe after a game stream
  (idempotent; sink restore is a no-op unless the capture sink is still default).
- Removes the video and session mode files: leaving "game" behind would be a
  statement about a stream that no longer exists.

### stream-mode.sh

`stream-mode.sh game|desktop`. The two clients want opposite things from
workspace 11: **game** (Steam Deck via "Steam Big Picture") is one fullscreen
window with the pointer confined, a dedicated game display; **desktop** (BCLT via
Moonlight's "Desktop" app instead of RDP) is an ordinary tiling workspace, since a
remote desktop that fullscreens every terminal isn't one.

Called twice, deliberately: from `stream-start.sh` (before the output exists, so
`stream.lua`'s `monitor.added` already knows the mode) and from the "Desktop"
app's prep-cmd in `apps.json`. Sunshine's per-app environment is the only
documented carrier of `SUNSHINE_APP_NAME`; if it doesn't reach a *global* prep
command on some build, the second call still gets desktop mode right. Both are
idempotent.

Anything other than `desktop` means game (same defaulting as `stream.lua`'s
`set_mode()`). The session file is written *before* the eval so a racing
`hyprctl reload` reads the mode being moved to. `hyprctl eval` runs in the same
Lua state the config was loaded into, so `require()`'s cache is the whole
interface to `stream.lua`: no socket, daemon, or generated file. If `stream.lua`
failed to load, `package.loaded.stream` is nil and the call errors, which is the
wanted signal (the log says the compositor side isn't there) rather than silently
streaming with the wrong rules. It also drives `desktop-audio.sh on|off`.

### desktop-audio.sh

`desktop-audio.sh on|off`, called only by `stream-mode.sh`. Points the system
default sink at the sink Sunshine captures for the duration of a desktop stream.
Why it's needed: see [Audio](#sunshineconf) above (Sunshine moves the default to
`sink-sunshine-stereo` while capturing `sunshine-stream`; anything following the
default is heard nowhere). Game streams pin via `PULSE_SINK`; a desktop stream
launches nothing, and every window is opened later by Hyprland. `virtual_sink` is
not the fix: gated to Windows in the Web UI.

- **Why it polls.** Sunshine sets its default *after* the prep commands return
  (prep at :18.0, sink moved at :18.970 in the log). Setting the default from the
  prep command would be overwritten a second later, so a detached child waits for
  Sunshine's move then takes it back. Detached (`setsid`, every descriptor closed)
  because Sunshine waits for a prep command to exit and a child holding stdout is
  a child it waits for too. 30 x 0.5s is a wide margin around the observed ~1s and
  exits the moment it sees the move.
- **Re-reads the session mode** rather than trusting the one it started in: a
  stream ending and being replaced by a game stream inside the poll window must
  not have its default sink yanked by a leftover child.
- **Only records a desk sink** as "previous" (not `sink-sunshine-*`, the captured
  sink, or empty): a reconnect inside the same stream would find Sunshine's own
  sink and make "restore" mean "leave it broken".
- **`off`** is a backstop. Sunshine restores the default it saved before its own
  move on a clean disconnect; this covers Sunshine dying or a client vanishing,
  which would leave the desk playing into the capture sink.
- Doesn't source `hyprctl-env.sh`, same reason as the ollama hooks: audio routing
  has nothing to do with the compositor being up.

### launch-bigpicture.sh

Brings up Steam Big Picture. Replaces a bare `setsid steam
steam://open/bigpicture` in `apps.json`, which fired the instant the prep-cmd
returned and raced Steam's startup: on a cold connect Big Picture never appeared,
while a reconnect worked because Steam was warm. Best-effort: if it gives up the
client still has a working desktop stream, better than a failed launch.

**Never exercised as of the logging work**: every Sunshine session on record
launched "Desktop" instead, so none of the polling has run against a real Steam.
It is instrumented more heavily than the other hooks because the first real run
is also its first test, and every `exit 0` is indistinguishable from success
without a log line saying which fired.

- `bigpicture_up` is proof the URL did something (the `steam://` handler exits 0
  whether or not a window appeared). Deliberately doesn't check *which*
  workspace: Steam maps onto whatever has focus and moving it to workspace 11 is
  `stream.lua`'s capture rule.
- `steam_windows` logs the real class/title values for when the match fails,
  since the failure mode is the class or title not being what was expected.
- Steam forks through a bootstrapper and re-execs, so wait for the process rather
  than assuming. `sleep 2` past process start: it accepts the URL before it can
  act on it.
- Three attempts then `exit 0` with a loud log line (this used to be silent and
  looked identical to success).

## hypr/stream.lua

Everything that exists only while Moonlight is connected. Replaced the
workspace-11 block in `hyprland.conf` and `sunshine/hooks/stream-focus.py`, a
standalone Python daemon parsing socket2. That daemon existed because hyprlang
couldn't express "fullscreen whatever lands on workspace 11":
`windowrule = fullscreen true, match:workspace 11` parsed but never applied. Lua
documents `match.workspace` as a real window-rule prop, so the rule is primary and
the event handlers are a backstop.

**Two session modes** (also in the README): game = every window on 11 forced
fullscreen, pointer confined, stray Steam windows pulled on; desktop = same
virtual output but an ordinary tiling workspace with borders and a free pointer.
The game rules aren't harmless in desktop: they'd fullscreen every terminal and
trap the cursor. The hooks choose via `set_mode()` through `hyprctl eval`
(shared Lua state).

- **`print()` lands in Hyprland's log** (`hyprctl rollinglog`), so this side
  needs no log file like the shell hooks.
- **State files** (`MODE_FILE`, `SESSION_FILE` in `XDG_RUNTIME_DIR`, removed by
  `stream-end.sh`): "no file" means "no stream" and a reboot can't leave a stale
  one. They exist for `hyprctl reload` (MOD5+SHIFT+c or any tool triggering one)
  re-running this file mid-stream; without them it would re-apply a hardcoded
  mode, which is how a 1080p stream to a docked Deck got snapped to 1280x800.
- **`M.streaming()`** is derived from the headless output existing, not tracked,
  so there's no flag to desync: `stream-start.sh` creates it, `stream-end.sh`
  removes it, nothing else makes one.
- **Video mode** is the client's, never this host's idea of one. Fallbacks in
  order, never a hardcoded resolution: (1) the mode file; (2) the mode the output
  is already running at (a reload finding a live stream but no file mustn't resize
  what someone is watching; observed: writing the file auto-reloaded Hyprland
  mid-stream and took a 1280x720 session to 1920x1080 with no hook involved);
  (3) `preferred`, reached only with no stream at all. The rule must name the
  output whichever branch wins, or the catch-all in `hyprland.lua` reclaims it on
  reload.
- **Two workspace rules, exactly one enabled** (`set_mode()` owns that): a
  workspace rule's props can't change after creation, only `enabled` can be
  toggled (`hyprctl workspacerules` prints it; that's how this was verified).
  Game: no gaps/borders/rounding so it looks like a dedicated display (polarity
  flip from hyprlang: `border:false, rounding:false` is `no_border`/`no_rounding`).
  Desktop: binding only; gaps and borders are how you tell which window has focus.
- **Crop mitigation** (`stream-game` rule, matched on workspace so it can't reach
  local play on DP-3/DP-1). Failure: a game asks X how big the display is, gets a
  physical monitor's size, renders at that, and the encoder gets the top-left crop
  of a larger image. `suppress_event fullscreenoutput` drops a client's request to
  fullscreen onto a *different* output (the request behind the crop);
  `suppress_event x11configurerequest` stops an XWayland game resizing its own
  window out from under the frame; `sync_fullscreen` forces Hyprland's internal
  fullscreen state and the one sent to the client to agree (a mismatch is the
  crop); `confine_pointer` because host and stream share one seat, so otherwise
  the desk mouse wanders off the virtual output mid-game (keybinds are handled by
  the compositor and still fire, so MOD5+SHIFT+s is an escape hatch). All wrong in
  desktop mode: confined pointer can't reach a second window.
- **`stream-capture` rule** pulls Steam onto the stream: Steam maps windows onto
  whatever workspace has focus and focus drifts (desk mouse moves, or a cold Steam
  start takes long enough that `stream-start.sh`'s focus call is ancient
  history). Can't pin at launch: the `steam://` URL is handled by the already
  running Steam. Enabled only while a client is connected and only in game mode,
  or it would yank Steam off the desk during local play (or onto the stream from
  the desk in desktop mode).
- **`pull_workspace(id)`**: the one thing a desktop stream can't do unaided.
  Focusing a workspace on another monitor moves *focus* to that monitor, so from
  the client MOD5+2 would send keystrokes to a window on the desk you can't see.
  This moves the workspace to the virtual output first. Bound to `MOD5+CTRL+<n>`
  in `keybinds.lua`; off-stream it degrades to a plain focus.
- **`go_fullscreen`**: `action = "set"` is an idempotent setter. The old Python had
  to read state first because the bare `fullscreenstate` dispatcher toggles,
  turning a window that maps already-fullscreen back into a tile.
- **`window.open` backstop**: harmless if the rule already worked (idempotent), so
  it stays whether or not `match.workspace` applies. Gated on game mode (a desktop
  that fullscreened everything would be unusable), and the gate must be here as
  well as on the rule since the handler doesn't consult it. A 400 ms `hl.timer`,
  never a sleep: callbacks run on the compositor event loop and blocking freezes
  the desktop; some games map then request fullscreen themselves a moment later.
- **`window.close` handler**: Hyprland allows one fullscreen window per
  workspace, so the game going fullscreen dropped Big Picture to a tile; when the
  game exits nothing restores it. Picks the lowest `focus_history_id` (most
  recently focused).
- **Focus is left on the streamed window**: host and stream share one seat, so the
  game only gets input while it holds focus; handing focus back would send client
  keystrokes to a desktop window.
- **`M.set_mode(...)` is last**, since it reads `M.streaming()` and touches every
  rule above. `SESSION_FILE` makes a mid-stream reload keep the running mode
  instead of reverting to game.
