# OpenRGB (bcpc)

The GPU, board, DIMMs and DualSense lightbar in the terminal palette, with a
gradient drifting across them. Playbook side (detectors, profile, restarts):
[ansible.md](ansible.md#openrgbyml).

## openrgb-server.service

`openrgb/openrgb-server.service` -> `~/.config/systemd/user/openrgb-server.service`

**User unit, not the packaged `openrgb.service`.** That one runs as root with
config in `/etc/openrgb`, so it would keep a second copy of the settings the GUI
edits in `~/.config/OpenRGB`, and it would need nothing a user unit lacks: the
openrgb package's udev rules tag the I2C and hidraw nodes `uaccess`, giving the
active seat session an ACL.

**No `[Install]`.** That ACL exists only once the login session is active, and
nothing on this host marks that for the user manager: Hyprland isn't started
through uwsm so `graphical-session.target` is never reached, and `default.target`
comes up alongside the session rather than after it. `hypr/bcpc.lua` starts
`iceberg-rgb.service` on `hyprland.start`, when the session is unambiguously
active, and that pulls this in.

**`--profile Iceberg`** paints the static gradient the moment detection finishes,
before any client connects. It's the snapshot `iceberg-rgb --save-profile` makes
and what stays on the hardware whenever the daemon is stopped. An absent profile
is logged and skipped, not fatal.

With the server running, opening the OpenRGB GUI connects to it as a client
instead of detecting hardware itself. That matters: two processes driving the same
SMBus devices is how ENE controllers get confused.

## iceberg-rgb.service

`openrgb/iceberg-rgb.service` -> `~/.config/systemd/user/iceberg-rgb.service`

Started from `hypr/bcpc.lua` on `hyprland.start`, not enabled (see above).
`BindsTo=openrgb-server.service` pulls the server in and takes this down if the
server goes, so starting this one unit is the whole switch. The daemon doesn't
need the server to have finished detecting: it retries the connection and
re-reads the device list whenever the server says it changed.

**Tuning** lives on the `ExecStart` line, not in the script's defaults. To try a
variant: stop the unit, run `iceberg-rgb --dim ... --dim-at ...` in a terminal
until it looks right, copy the flags onto the unit, then
`systemctl --user daemon-reload && systemctl --user restart iceberg-rgb`. See
`iceberg-rgb --help` for speed, spread, direction, colour.

## iceberg-rgb.py

`openrgb/iceberg-rgb.py` -> `~/.local/bin/iceberg-rgb`

**What it is.** A client of the OpenRGB SDK server, not a plugin or a profile. A
profile is a snapshot: it can hold a gradient but can't move one, and OpenRGB's
hardware modes run per device with no idea where the others are. So this places
every LED at a physical position in the case and paints one colour field across
all of them, drifting slowly left to right.

**Static profile.** `--save-profile Iceberg` paints frame zero and saves it,
because the server loads that profile at startup (covers the window before this
connects and any time it's stopped). The save goes through the `openrgb` CLI: 1.0
honours `SAVE_PROFILE` only from its own local client and silently drops it from
any other SDK client, this one included. Run it with the daemon stopped or the
daemon's next frame lands in the snapshot.

**Stdlib only.** The SDK wire format is small enough that the AUR `python-openrgb`
would be a dependency for ~100 lines of struct packing, and it lags the server's
protocol version.

**Colours.** Read from kitty's generated theme, so they follow whatever palette
Noctalia last applied (see Noctalia in [ansible.md](ansible.md#configyml)), and
re-read when the file changes. Hex values are sRGB for a screen; an LED's PWM duty
is linear light, so `#84a0c6` fed straight to an LED is a near-white wash. Each
stop is decoded to linear light, interpolated in OKLab (even-looking blends, no
grey dip between hues), and scaled so its brightest channel is full on.
`PALETTE = (6, 4, 5)` are terminal palette indices (Iceberg's cool half: cyan,
blue, lavender), looping back to the first. `FALLBACK` is Iceberg for when neither
kitty file exists.

**Cost.** This process is a table lookup per LED per frame: noise. The cost is in
the server, almost all of it the GPU. Measured on bcpc by animating one device at
a time and reading the server's CPU time from `/proc`:

```
DRAM x2, board, keyboard @ 20 fps   a few % of one core, all together
                                    (keyboard since dropped, see below)
GPU @ 2 / 4 / 8 fps                 12% / 22% / 42%, nearly all kernel
```

About 5% of a core per GPU frame per second. The card's LEDs sit on the NVIDIA
driver's I2C adapter, where each of the 29 LEDs costs ~1.8 ms of busy kernel time
per write. OpenRGB 1.0 queues writes on per-device threads, so the SDK gives no
back-pressure and a round-trip can't see any of this; `/proc/<pid>/stat` is the
only honest meter.

So the GPU isn't given frames at all. It gets a budget of single-LED writes per
second (`--gpu-writes`), and each 20 fps tick spends its share on whichever LEDs
are furthest from where the wave says they should be. Measured, a single-LED write
costs the same as one LED's share of a full frame (58 writes/s: 12.2% of a core as
singles, 11.0% as two 29-LED frames), so it's the same money spent better. The
first version gave the GPU 2 full frames a second, and with a brightness dip on
(`--dim`) the whole card visibly ticked in unison; simulated over a minute of the
wave, worst-case lag behind target fell from 0.28 to 0.08 (perceptual units,
`--dim 0.6 --dim-at 0.85`), and the LEDs no longer all move at once.

Unchanged frames are never sent, and the whole thing freezes while gamemode has a
client, so nothing touches the GPU's I2C bus while a game runs. gamemode is polled
over D-Bus (`ClientCount`, ~6 ms a read, every 5 s) rather than driven by
`[custom]` hooks in `gamemode.ini`: a hook fires only on the transition, so a
daemon restarted mid-game would come back animating; a poll can't miss the state.
`SIGUSR1`/`SIGUSR2` still freeze and resume by hand, e.g.
`systemctl --user kill -s USR1 iceberg-rgb`.

**Layout.** Front view into the case, origin top-left, y down, units roughly cm.
Only relative positions matter: they decide which LEDs share a colour and which
way the gradient appears to travel.

```
    logo                        ::  DIMMs. LED 1 is the top, the end
       `-.                      ::  furthest from the GPU. The 0x73 stick
          +--+                  ::  stands in front of the 0x71 one, so
          |  |  GPU front,      ::  from here they overlap.
          |  |  a loop of LEDs
          +--+
          [==]  chipset accent, directly beneath the GPU
```

The GPU's 29 LEDs are one run in index order, mapped on the hardware with
colour-block test patterns rather than from any datasheet: LEDs 0-6 trace the logo
toward the front of the card, then 7-28 go clockwise round the front from its
top-left corner (top edge to about 9.5, right edge to about 17, back up the left
side to where the loop started). `GPU_PATH` waypoints are (LED index, x, y); LEDs
between two waypoints are spaced evenly along the line joining them.

**No keyboard.** The Wooting 60HE+ has switches with no LED window, and OpenRGB
driving its RGB interface is reported to clash with some of Wooting's own
settings, so the playbook turns its detector off and the server never sees it.
