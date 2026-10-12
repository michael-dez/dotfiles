# Hyprland (bcpc)

Config is Lua, not hyprlang (upstream deprecated hyprlang in 0.55). CachyOS has
no `cachyos-hyprland-settings` package, so `hypr/hyprland.lua` is ours rather than
an override of a shipped file. Each `require()` is its own error scope, so a
mistake in one fragment doesn't take down the config. Module lookup follows the
symlinks `install.yml` creates; paths resolve relative to `~/.config/hypr`.
Streaming rules are in [streaming.md](streaming.md#hyprstreamlua).

`hyprland.lua` requires fragments last-wins: `decoration`, `animations`, `bcpc`
(host input/env), `gaming` (local play), `stream` (workspace 11), `keybinds`
(binds last because they reference everything above).

## hyprland.lua

- **Monitors.** ZOWIE (540 Hz, 1080p) on the left (DP-3), Alienware ultrawide on
  the right (DP-1). The empty-output rule is the fallback used only when no other
  matches; it doesn't race the `sunshine` rule in `stream.lua` the way the
  hyprlang equivalent did, because matching is by specificity not file order.
- Workspaces 1 and 2 are bound to DP-3 and DP-1 so windows have a predictable
  landing place.
- **`allow_tearing = true` is only the master switch.** Nothing tears because of
  it; it stops Hyprland refusing a client that asks to (otherwise logged in
  `hyprctl rollinglog` as "Tearing commit requested but the master switch
  general:allow_tearing is off, ignoring"). The per-window opt-in is the
  `immediate` rule in `gaming.lua`, so the desktop pays nothing. Paired with
  `vrr = 0` on purpose: tearing and VRR are two answers to one question, and a
  540 Hz panel is already the "show me the newest frame" answer.
- Autostart is `hl.on("hyprland.start", ...)`, the Lua `exec-once`; `hl.exec_cmd`
  is asynchronous, no `& disown`.

## bcpc.lua

Host-specific input and environment, required near the bottom of `hyprland.lua`
so it wins over defaults above it.

- **Env vars here, not `~/.zshrc.bcpc`**: zshrc runs only for interactive shells,
  so anything exported there is invisible to GUI apps launched from the Noctalia
  launcher. `hl.env` applies to the whole session.
- **Keyboard.** Replaces the `setxkbmap` call in zshrc, which can't work under
  Wayland. `lv3:ralt_switch` makes Right Alt a distinct modifier
  (`ISO_Level3_Shift` = Mod5) so it can be the Hyprland mod key without capturing
  Left Alt, which applications still need. Cost: Right Alt no longer types AltGr
  third-level characters. See `mod` in `keybinds.lua`; Sunshine's
  `key_rightalt_to_key_win` must stay disabled for this.
- **Mouse: flat, unscaled deltas.** Not a comfort preference: Hyprland runs
  pointer motion through libinput's acceleration before it reaches *any* client,
  including the relative-pointer stream a game reads for mouselook. On the default
  "adaptive" profile a slow drag and a fast flick of the same distance become
  different in-game distances, which is what a raw-input mode exists to avoid.
  - `accel_profile = "flat"`: no curve.
  - `sensitivity = 0`: the neutral point of -1.0..1.0, **not** "off" (0 is 1:1). It
    is the default, so it documents intent; `accel_profile` does the work.
  - Deliberately not `force_no_accel`: that bypasses the pointer pipeline rather
    than flattening it, and the wiki's warning about cursor desynchronisation is
    the failure you'd then chase.
  - Global, not per-device (`hl.device`): the desk mouse isn't the only pointer on
    the seat (the Wooting's HID mouse endpoints appear in `hyprctl devices` as
    mice), and a per-device block covers only a name that happens to be plugged in.
- **Mouse DPI: `solaar --window=hide` at start.** The PRO X 2 DEX powers on with
  its onboard profile (800 DPI). `~/.config/solaar/config.yaml` already asks for
  `onboard_profiles: 0`, `dpi_extended: 1200`, but nothing ever applied it: solaar
  ships no systemd unit, there's no `~/.config/autostart`, and no `exec_cmd`
  launched it, so it only ran when started by hand. Measured: on a fresh boot
  `solaar show` reports saved `{X:1200, Y:1200}` against live `{X:800, Y:800}`;
  starting the daemon flips live to 1200 with nothing else touched. A resident
  daemon, not a one-shot `solaar config ... dpi 1200`: this is a wireless mouse
  that sleeps and re-pairs, and re-applying on return is why solaar stays
  resident; a one-shot holds only until the first sleep. `--window=hide` keeps it
  out of the tray. A second `hyprland.start` handler is fine; host hardware lives
  here rather than in the generic list in `hyprland.lua`.
- **RGB.** `systemctl --user start iceberg-rgb.service` at start, not an enabled
  unit: the OpenRGB server reaches I2C/hidraw through `uaccess` ACLs which only
  exist once the login session is active, and this is the first point on this host
  guaranteed to be. `BindsTo` in `iceberg-rgb.service` pulls the server in. See
  [rgb.md](rgb.md).
- **NVIDIA.** 4070 Ti (Ada) on the open kernel modules. Deliberately not setting
  `WLR_NO_HARDWARE_CURSORS` or `GBM_BACKEND`: pre-explicit-sync advice that causes
  problems on current drivers.
- `ELECTRON_OZONE_PLATFORM_HINT=auto` stops Electron/Chromium flicker by forcing
  native Wayland.

## keybinds.lua

Converted from `i3/config`. i3 used `$mod = Mod1` (either Alt); here `mod` is
**Right Alt only** (`MOD5`): Hyprland modmasks can't tell left from right, so
`bcpc.lua` maps Right Alt to `ISO_Level3_Shift` = Mod5 and Left Alt stays ALT for
application shortcuts. Bindings with no Wayland equivalent are noted below rather
than silently dropped.

- **`MOD5+SHIFT+q` is force-kill**, for when `MOD5+q` is ignored. `close` is only
  a polite request (an `xdg_toplevel` close, or `WM_DELETE_WINDOW` for XWayland)
  and a hung game never services it. `kill` = `forcekillactive`: SIGKILL to the
  focused window's PID, verified on a throwaway kitty (shell reported 137). It
  rescues a wedged *client*, not a wedged *system*: a compositor short of memory or
  CPU can't run the bind. Alt+SysRq+F is the escape hatch for that; see
  [system.md](system.md#sysrq).
- Split binds: i3 split h/v maps to dwindle's `preselect r`/`preselect d`;
  `togglesplit` for layout toggle split. i3 stacking/tabbed map to Hyprland groups
  (`group.toggle`, `group.next`) as the nearest native equivalent.
- Focus/move: vim keys and arrows built from one table.
- **Workspaces.** Three keys each: the number row, numpad with numlock OFF (i3
  used bindcode), numpad with numlock ON (i3 used the Mod2 duplicates). Workspace
  10 is on `0`.
- **`MOD5+CTRL+<n>` is the stream's half**: brings workspace N *to* the virtual
  output instead of sending focus to the monitor that holds it; without it a
  desktop stream only ever sees workspace 11. See `pull_workspace()` in
  [streaming.md](streaming.md#hyprstreamlua); off-stream it is a plain focus.
  `hl.bind` takes a Lua function, which lets one binding choose between two
  behaviours at press time.
- Multi-monitor: i3's "move workspace to output next/eDP" has no eDP equivalent
  on a desktop, so both directions are next/previous monitor.
- `MOD5+SHIFT+x` hyprlock (was `Mod4+Shift+l` blur-lock) moved off `SHIFT+l`,
  which is now "move right".
- **`MOD5+SHIFT+s` runs `stream-end.sh` by hand**, the escape hatch for a stranded
  stream: if Moonlight dies without disconnecting cleanly Sunshine never fires its
  undo hook and the invisible `sunshine` output keeps workspace 11 and its windows.
  Safe when not streaming (the hook no-ops and logs it).
- Media: `locked` keeps them working over a lockscreen; `repeating` is the old
  `bindel` `e` flag. Volume 5% bare, 1% with mod. Brightness is DDC/CI via
  `ddcutil` (desktop has no backlight, so not `xbacklight`).
- Resize submap: i3 had it commented out; restored. A submap needs a way out or
  you're stuck; recover from a TTY with `hyprctl dispatch 'hl.dsp.submap("reset")'`.

**Not converted from i3:**

| i3 | why |
|---|---|
| `$mod+Shift+r` restart in place | no equivalent; reload covers config, and Hyprland can't re-exec preserving layout |
| `$mod+a` focus parent | dwindle has no parent-focus concept |
| `$mod+Shift+n` `scripts/empty_workspace` | i3-specific (used `i3-msg`) |
| `$mod+p` switch-audio-port | X11/i3blocks; use Noctalia's audio panel or `wpctl set-default` |
| `$mod+Shift+p` `scripts/power-profiles` | rofi+X11; `powerprofilesctl` works, the menu script doesn't |
| F1 `scripts/keyhint-2` | rendered an X11 image of the cheat sheet |
| i3blocks pkill signals | i3blocks isn't running; Noctalia owns the bar |

## decoration.lua

- Hyprland's blur has no percentage scale: `size` is a pixel radius, `passes` the
  repeat count; 3/2 is a light blur. `vibrancy` is the one 0-1 knob. Terminal
  translucency lives in `kitty.conf` (`background_opacity`) because a window-level
  opacity rule would dim the text too. No per-window rule turns blur *on*:
  Hyprland blurs behind any translucent surface when `decoration.blur.enabled`;
  there is only `no_blur` to exempt.
- **`mute()`** scales a `#rrggbb` by a factor rather than pasting a muted hex, so
  the border follows `BORDER_BASE` down. `BORDER_BASE` is `mPrimary` from
  `noctalia/palettes/Iceberg.json` (also where kitty gets colours), hardcoded
  because it's JSON, Lua has no bundled parser, and the palette changes about
  yearly. Noctalia could generate this via its `hyprland` builtin template, but
  `noctalia/settings.toml` enables only `kitty`, so this is the sole owner of
  `general.col`. 0.8 = 20% less bright = `rgb(6a809e)`.
- `inactive_border` left at Hyprland's `0xff444444`: a neutral grey is what keeps
  the muted blue reading as "focused" at a glance.
- **`dim_strength = 0.15`**, not the 0.5 default: on a 3440-wide panel most of the
  screen is unfocused at any moment and 0.5 makes the desktop look switched off.
  Easing is `fadeDim` in `animations.lua`.
- **Shadow**: default range 4 with near-black is invisible except on a light
  wallpaper; wide, soft, low-opacity reads better, offset down to look lit from
  above. `render_power` is a 1-4 falloff exponent where *lower* is softer.
  `range = 20` is deliberately wider than `gaps_out` (8) so shadows fall across
  neighbouring windows.
- **`steam-game-chrome` rule** is global on purpose: the one exemption that must
  reach both local play (`gaming.lua`) and streams (`stream.lua`), so it is scoped
  to the game, not the display.
  - **Class, not content**: `content = "game"` comes from the Wayland content-type
    protocol and Proton never sets it (`contentType` "none" on XWayland and on
    native Wayland via `PROTON_ENABLE_WAYLAND=1`/`winewayland.drv`; see
    [gaming](#gaminglua)). The old content variant matched nothing so a Steam
    game still dimmed on focus loss; removed because a rule that can't fire reads
    as coverage.
  - **Anchored at both ends, load-bearing**: `match.class` is a full match, not a
    search; bare `^steam_app_` matches nothing, silently. Verified with both forms
    on one window at one reload: `^steam_app_` left `no_dim` false,
    `^steam_app_.*$` made it true, read back with `hyprctl getprop <regex>
    no_dim`, the only honest oracle (an unknown or misspelled rule prop is
    accepted without error and ignored).
  - `^steam$` (client library/store windows) is deliberately excluded; they are
    desktop windows.
  - `no_anim` also covers the `animations.lua` curves. Border colour is not
    exempted (a global with no per-window opt-out); a fullscreen game has no
    border (`gaming.lua`, `stream.lua`), so only a windowed Steam game sees the
    muted blue.

## animations.lua

Target feel: motion that accelerates hard then stops dead, nothing overshoots or
wobbles. Both springs sit just above critical damping: for mass m and stiffness k,
critical `dampening = 2 * sqrt(k * m)`; below that a spring overshoots, at/above
it settles without crossing the target. Raising stiffness (and dampening with it)
speeds motion without making it bouncier. `speed` is in ds (1 ds = 100 ms) and
scales the whole curve; reach for it, not the spring constants, if it feels too
quick or slow. Steam games are exempt via `no_anim` in `decoration.lua`.

- `settle`: 2*sqrt(300) = 34.64, so 35 is a hair overdamped. `snap`:
  2*sqrt(420) = 40.99, stiffer, for motion the pointer is already driving.
- Bezier points are the two *middle* control points (endpoints fixed at {0,0} and
  {1,1}), so they read like CSS `cubic-bezier()`. `linear` is built in.
- `global` is the floor; unset leaves inherit their parent, so everything below
  exists only where one uniform curve is wrong.
- Opening scales up from 92% under a spring; closing is a fast, nearly linear
  shrink. Deliberate asymmetry: windows arrive with weight and leave without
  ceremony (`windowsOut` is about half `windowsIn`).
- Fades are quick and mostly linear; a fade that eases is a fade you notice.
  `fadeSwitch`/`fadeShadow`/`fadeDim`/`border` all fire on a focus change so they
  share a speed, else four things settle at four moments and one focus change
  reads as four events.
- Layers (Noctalia bar, launcher, notifications) fade rather than slide so chrome
  doesn't compete with window motion.
- Workspaces: flat horizontal slide on a symmetric ease so left looks like right.
  Not a spring: a spring across the whole desktop feels like a rubber band.

## gaming.lua

Rules for games played locally on DP-3 / DP-1.

**Matched on class, not Wayland content type.** Under Proton:

```
hyprctl clients -j | jq '.[] | {class, xwayland, contentType, xdgTag}'
{ "class": "steam_app_2357570", "xwayland": false,
  "contentType": "none", "xdgTag": "proton-game" }
```

`xwayland: false` is the `PROTON_ENABLE_WAYLAND=1` launch option: proton-cachyos
loads `winewayland.drv` instead of `winex11.drv`, so Overwatch is a native Wayland
client. (An earlier note recorded `xwayland: true`, true before the option.) The
conclusion survived for a different reason: `contentType` is *still* "none"; Wine
doesn't set the content-type protocol on a game surface whichever driver, so
`content = "game"` matches nothing and every rule would be dead config (which is
why a Steam game landed in a tile with rounded corners and dimmed on focus loss).
`xdgTag = "proton-game"` is the honest "a Proton title" matcher but only covers
Wayland-native clients; class covers those and anything still on XWayland.

**Tradeoff**: class rules can reach a game on workspace 11. The overlap with
`stream.lua` is harmless (same fullscreen state, same pointer confinement, a
streamed game is simply told twice) but this file is no longer structurally
incapable of touching a stream. The event handler stays scoped to workspace != 11
to avoid racing.

**`GAME_CLASS = "^steam_app_.*$"`, anchored at both ends**: `match.class` is a full
match; a bare `^steam_app_` silently matches nothing (which left the first pass as
dead as the content rules it replaced). `.*$` is also a valid Lua pattern, so one
constant serves the rule matcher and the `w.class:match()` backstop.
`STREAM_WORKSPACE = 11` is `stream.lua`'s, not ours.

- **`local-game-pointer`**: keep the cursor in the game. With a 540 Hz panel beside
  a 3440-wide one, mouselook running off onto the other monitor mid-fight is a real
  hazard and most games only half-manage pointer lock. Gated on fullscreen so a
  windowed game, or a launcher mapping under the same class first, doesn't trap the
  pointer in a small window; that gate was inert while the class half never
  matched.
- **`local-game-fullscreen`**: there was previously no rule outside workspace 11, so
  a local game only went fullscreen if the title did it (Overwatch doesn't, hence
  the tile). `fullscreen_state "2 2"` = internal and client both fullscreen (same
  pair `stream.lua` asks for); `sync_fullscreen` forces agreement (a mismatch leaves
  a game rendering at the wrong size); `suppress_event x11configurerequest` stops an
  XWayland title resizing out of fullscreen. **Not** `fullscreenoutput`: that exists
  to pin a stream to the virtual output and suppressing it here would block a
  legitimate "go fullscreen on the other monitor" on a two-panel desk.
- **`local-game-tearing`** (`immediate = true`): `general:allow_tearing` is only the
  master switch; with no per-window opt-in Hyprland still drops the client's
  tearing commits. Ungated on fullscreen because rules apply at map time when the
  game isn't fullscreen yet; self-gating in practice (a torn present needs the
  window to own the scanout plane, only a fullscreen one does). Two things outside
  Hyprland must agree for a real latency reduction: vsync off inside Overwatch, and
  `dxvk.tearFree = False` in `~/.config/dxvk.conf` (already pointed to by the
  `DXVK_CONFIG_FILE` launch option).
- **`local-game-chrome`** (`decorate = false`, `no_blur`): no desktop chrome on a
  game; blur is a per-frame cost paid for something mostly hidden. Deliberately
  **not** gated on fullscreen: rules apply at map when the game isn't fullscreen
  yet, so gating on a state that arrives afterwards reproduces the rounded corners
  this exists to remove; ungated also covers a game run windowed on purpose.
  `decorate = false` replaced `border_size = 0` / `rounding = 0`, neither of which
  is a window property (`hyprctl getprop <regex> no_border` / `no_rounding` ->
  "prop not found"; unknown props are accepted silently, so those lines did
  nothing). `decorate` is in the real property table, reads back false, and takes
  border, shadow and glow together. `no_dim`/`no_shadow`/`no_anim` live in
  `decoration.lua` because they must reach a streamed game too.
- **Fullscreen backstop**: same belt-and-braces as `stream.lua`: a rule applies at
  map time, but a Proton title may map small and settle a moment later.
  `action = "set"` is idempotent so it's free when the rule already worked (the
  bare `fullscreenstate` dispatcher toggles and would knock an already-fullscreen
  game back to a tile). Skips workspace 11 (two timers racing to fullscreen one
  window is how a game flickers on a cold start). A timer, never a sleep: callbacks
  run on the compositor event loop and blocking one freezes the desktop.

## kitty

`kitty/kitty.conf` -> `~/.config/kitty/kitty.conf`

- **Translucency is set in kitty** (`background_opacity 0.75`), not with a Hyprland
  `windowrule opacity`: that rule dims the whole surface including the text. This
  way only the background is translucent and glyphs stay opaque; Hyprland blurs
  whatever shows through (`decoration.lua`).
- Background/foreground are neutral greys, no blue or warm cast, so they sit under
  any Noctalia palette.
- **Two includes, in this order; the order is the point.** `colors.conf` is a
  static Gogh export of Iceberg, checked in: the fallback, giving kitty the right
  colours on a fresh machine before Noctalia has run its templates.
  `themes/noctalia.conf` is generated by Noctalia's built-in kitty template every
  time the active palette changes and is deliberately **not** in the repo (output,
  not config). Coming last, it wins, so kitty tracks Noctalia's palette. With the
  Iceberg custom palette active the two agree exactly; switch Noctalia to another
  palette and this is what retints kitty. A missing include is only a warning
  ("Could not find included config file ..., ignoring"), so the second line is
  harmless where Noctalia hasn't applied templates yet.
