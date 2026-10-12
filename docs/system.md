# System configs (`system/`, `gamemode/`)

Rationale for the host-level configs. Each section is linked from a one-line
pointer in the config itself.

## earlyoom

`system/earlyoom-override.conf` -> `/etc/systemd/system/earlyoom.service.d/override.conf`

**Why a drop-in, not `/etc/default/earlyoom`.** The packaged unit reads
`EARLYOOM_ARGS` from `/etc/default/earlyoom`, which pacman owns (`.pacnew` on
upgrade). pacman never writes `/etc/systemd/system`. The EnvironmentFile route
also has a sharp edge: systemd splits `$EARLYOOM_ARGS` on whitespace *without*
removing quotes, so a quoted regex reaches earlyoom with literal quote
characters and silently never matches. On an `ExecStart` line words are quoted
normally. Two caveats, both verified by dumping what the process received:

- A trailing `$` is safe: systemd only expands `$` that begins a valid variable
  name or `${...}`.
- A backslash is not: `\.` is not a C-style escape systemd knows, so it logs
  "Ignoring unknown escape sequences" on every daemon-reload. Write the dot as
  the POSIX class `[.]`.

**Why this layer exists on top of zram.** zram widens the margin but doesn't
remove the failure mode: a leak larger than the device fills it and stalls
anyway. The kernel OOM killer fires only when reclaim makes zero progress, which
it can postpone by thrashing executable text pages while everything sits in
page-fault I/O. earlyoom reads MemAvailable from userspace and acts while the
machine is still interactive.

**Flags.**

- `-m 10,5`: SIGTERM at 10% MemAvailable, SIGKILL at 5% (earlyoom's defaults).
  Idle headroom is far above that, so it arms only during a real runaway.
- `-s 100,100`: ignore swap in the trigger. earlyoom needs memory AND swap both
  under their minimums before acting; our swap is zram, in the RAM being
  protected, so at the default it would wait until zram filled too, by which
  point the compressed pages have eaten the headroom. 100 makes the swap clause
  always true.
- `-r 3600`: report interval. Default 1 writes a journal line every second.
- `--avoid`: compositor and sshd. Killing them turns a recoverable incident into
  a lost session; sshd is the remote escape hatch.
- `--prefer`: what the box can afford to lose first: the browser and both
  Claudes (the Electron app and the CLI are separate processes with separate
  comm names).

**Why `^.*[.]exe$` is not in `--prefer`.** `--prefer` is a flat +300 with no
tiers, so a preferred game beats a preferred browser by whatever margin its RSS
earns. Leaving `.exe` neutral gives three tiers: +300 disposable apps, 0 game,
-300 session. Both Overwatch installs (Steam and the Battle.net non-Steam
shortcut) name their binary `Overwatch.exe`, so neither needs its own rule.
Steam does *not* set `oom_score_adj` on the titles it launches: `Overwatch.exe`
runs at adj 0 and ranks on RSS alone. The adj=300 in that tree is on
`steamwebhelper` (Chromium for its own renderers).

**Why the two LLM containers are not in the regex.** `--prefer` matches
`/proc/pid/comm`. Measured:

| container | comm | note |
|---|---|---|
| langflow | `langflow` | renames itself (setproctitle / PR_SET_NAME) |
| open-webui | `python3` | execs `python3 -m uvicorn open_webui.main:app`, never renames |

`python3` can't be a pattern: Proton starts games via
`python3 .../proton waitforexitandrun ... Overwatch.exe`, same comm. No regex
can separate the container to kill first from the launcher whose game to kill
last, and `--avoid` can't rescue it (+300 and -300 on the same process net to
zero). So both containers raise their own `oom_score_adj` via
`PodmanArgs=--oom-score-adj=450` (see [llm.md](llm.md#containers)); earlyoom
ranks on `/proc/pid/oom_score`, which already folds adj in. langflow could have
been matched by regex, but both carry `AutoUpdate=registry` on `:latest`, so a
process name is not a stable interface and a `--prefer` rule that quietly stops
matching is the failure to avoid.

**Why 450, not 300.** `/proc/pid/oom_score` = `(1000 + adj + rss_permille) * 2/3`,
so the whole range spans 666..1333. earlyoom's +300 is added to that compressed
number; `oom_score_adj` goes in before the 2/3. 450 * 2/3 = 300, so
`--oom-score-adj=450` is the exact equivalent of a `--prefer` match. Confirmed:
comm=langflow, adj=450, oom_score=973.

**Resulting order, with a 19 GiB `Overwatch.exe` resident:**

```
claude-desktop   876 +300 = 1176   (Electron already sets adj 200-300)
open-webui         -      =  985   (adj 450, container)
firefox          678 +300 =  978
langflow           -      =  973   (adj 450, container)
claude           670 +300 =  970   (the CLI)
Overwatch.exe    931   0  =  931
Hyprland         674 -300 =  374
```

firefox clears the game by 47 points, roughly 2.3 GiB of further game growth on
this scale. If a title outgrows that, move `'^.*[.]exe$'` into `--avoid` for
another 300. Not the default: it would also rank steam and steamwebhelper above
the game, so earlyoom would churn through helpers then kill the Steam client,
ending the title without reclaiming what the title held.

**Verify.**

```
systemctl status earlyoom | grep -iE 'prefer|avoid|sending SIGTERM'
```

Dry run (no root, signals nothing; `-m 99` holds it permanently "below"
threshold so it names a victim immediately):

```
earlyoom --dryrun -r 0 -m 99 -s 100 \
  --avoid '^(systemd|Hyprland|sshd|sunshine|pipewire|wireplumber)$' \
  --prefer '^(firefox|claude|claude-desktop)$'
```

## sysrq

`system/99-sysrq.conf` -> sysctl.d

Arch ships `kernel.sysrq = 16` (sync only). SysRq is handled in the kernel's
input path, so it works when userspace is too starved to schedule; Alt+SysRq+F
invokes the OOM killer and is the difference between a wedged machine and a lost
session.

`244 = 4 + 16 + 32 + 64 + 128`: keyboard control (4), sync (16, the stock
default), remount read-only (32), signalling of processes (64, Alt+SysRq+F),
reboot/poweroff (128). Not 1 ("everything"): that adds bit 8, debugging dumps,
which spray task backtraces into the journal on a keypress. 244 is what makes
REISUB work and nothing more.

The mask gates only the *keyboard*. Root writes to `/proc/sysrq-trigger` are
always permitted, so `echo f | sudo tee /proc/sysrq-trigger` over SSH works even
at the stock 16.

## zram

`system/zram-generator.conf` -> `/etc/systemd/zram-generator.conf`,
`system/99-zram.conf` -> `/etc/sysctl.d/99-zram.conf`

**Why swap at all.** The host had none: no partition, swapfile, or zram. bcpc was
built by hand rather than the CachyOS graphical installer, so `cachyos-settings`
(which ships a zram-generator config) never landed, and only the "no disk swap"
half of the policy took effect. Without swap, anonymous pages are unreclaimable,
so reclaim's only target is file-backed memory, which once page cache is gone
means running executables' own text pages. The kernel evicts them, the process
faults them back off NVMe, and the kernel scores that as progress, so the OOM
killer stays holstered while everything grinds. Swap gives reclaim a target that
isn't your executables, which breaks the loop.

**`zram-size = ram / 2`.** cachyos-settings uses `ram`. Halved on purpose:
compressed pages live in real memory, so device size is the worst-case physical
RAM swap can consume, and half is far more than breaking the loop needs. Raising
it is a one-line change. A leak larger than the device still fills it; see
[earlyoom](#earlyoom).

**zstd** matches the btrfs `compress=zstd:3` mounts in `/etc/fstab`.

**Sysctls.**

- `vm.swappiness = 150`: the default 60 assumes swap on spinning disk. Paging
  out to zram is roughly a memcpy, nearly always cheaper than the kernel's
  alternative (evicting page cache, then executable text). 150 is what
  cachyos-settings applies when its zram udev rule fires; 200 is valid, 180 is
  the other common figure; not worth deviating from the distro.
- `vm.page-cluster = 0`: no seek cost or readahead to amortise; clustering just
  burns decompression on pages nobody asked for.
- `vm.watermark_scale_factor = 125`, `vm.watermark_boost_factor = 0`: reclaim a
  little earlier and smoother so kswapd isn't repeatedly woken to sprint at the
  low watermark. Boost factor 0 disables the fragmentation-triggered boost,
  aimed at huge-page allocation and noise here.

## nvidia modprobe options

`system/nvidia-bcpc.conf` -> `/etc/modprobe.d/nvidia-bcpc.conf`

**The filename is load-bearing: it must not be `nvidia.conf`.** modprobe reads
`/etc/modprobe.d`, `/run/modprobe.d`, `/usr/lib/modprobe.d`, and per
modprobe.d(5) "a file of the same name in subsequent directories is ignored":
`/etc` wins on exact name match by suppressing the other file entirely, not by
merging. `cachyos-settings` ships `/usr/lib/modprobe.d/nvidia.conf`, so a local
`nvidia.conf` deletes it wholesale. The old hand-written one predated the
package so shadowed nothing; installing the package would have sprung it. Any
other name works. (`-bcpc` also sorts before `nvidia.conf`, since `-` 0x2D <
`.` 0x2E, and files are read in lexicographic order across all three dirs; it
doesn't matter because nothing here names a parameter cachyos-settings also
names.)

**Deliberately not here:**

- `NVreg_InitializeSystemMemoryAllocations` is left to cachyos-settings, which
  sets it to 0 (driver default 1). At 1 the driver zeroes every system memory
  allocation, and writing a page makes it resident, so pool slabs the GPU barely
  touches count fully against RSS. That is why Overwatch sits at ~18.5 GiB with
  ~12.5 GiB host-side, write-once, never read. It is a real security relaxation
  (freed memory isn't cleared before the GPU sees it); taking the distro value
  avoids re-litigating it every driver bump. To opt out, add
  `NVreg_InitializeSystemMemoryAllocations=1` to the options line; being in this
  file is enough to win.
- `options nvidia_drm modeset=1`, which the old file carried. `modinfo
  nvidia_drm` on 610.57.04 reports "1 = enable (default)". If a future driver
  flips that, the symptom is a dead Wayland session at next boot, revertible
  from a TTY.

**Ours:** `NVreg_PreserveVideoMemoryAllocations=1` saves VRAM to
`NVreg_TemporaryFilePath` across suspend. nvidia-utils already ships part of this
in `/usr/lib/modprobe.d/nvidia-sleep.conf` (`NVreg_UseKernelSuspendNotifiers=1`,
`NVreg_TemporaryFilePath=/var/tmp`), a differently-named file, so it merges
rather than being shadowed. Kept rather than dropped as presumed-redundant: the
two aren't verified interchangeable, and a corrupted framebuffer on resume is a
bad way to find out.

## uinput

`system/uinput.conf` -> `/etc/modules-load.d/uinput.conf`

Every input device Sunshine creates for a client (gamepad, keyboard, mouse,
touchscreen) is a uinput device. uinput is a module (`CONFIG_INPUT_UINPUT=m`),
normally autoloaded on first open of `/dev/uinput`, i.e. the first stream after
boot. A kernel upgrade replaces `/usr/lib/modules/<running version>`, so until
the next reboot the running kernel can load no module it hasn't already loaded.
Stream in that window and the open fails with ENODEV even though `/dev/uinput`
(a static node) exists:

```
Warning: create libvirtualhid gamepad: failed to open uinput device: No such device
```

Video and audio still work, so it looks like the Deck's input is ignored.
Loading at boot keeps the module resident across upgrades.

## gamemode

`gamemode/gamemode.ini` -> `~/.config/gamemode.ini`

Exists for one line: `pin_cores=no`.

**The problem.** gamemoded defaults to `park_cores=no`, `pin_cores=yes`, and per
gamemoded(8) the pinning autodetect "will currently only properly autodetect
Ryzen 7900x3d, 7950x3d and Intel CPU:s with E- and P-cores". The 14700KF is the
third case. It picks "good" cores by reading
`/sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq` and keeping the fast
ones: 5.6GHz on cpu8-11, 5.5GHz on the other P-cores, 4.3GHz on cpu16-27, so
the E-cores are dropped and the client process tree is pinned to 0-15.
Measured: under `gamemoderun` every one of `Overwatch.exe`'s ~100 threads had
affinity 0-15, against 0-27 without it.

The other discriminator, L3 size, is uniform here
(`/sys/devices/system/cpu/cpu*/cache/index3/size` is 33792K on all 28 CPUs,
E-cores share the one L3), hence a clean P/E split rather than the CCD split an
X3D part gets.

Dropping 12 of 28 logical CPUs suits a game with few latency-critical hot
threads. Overwatch under Proton isn't that: ~100 threads, with wine, DXVK and
shader-compile work in the same tree inheriting the same mask. Pinning doesn't
concentrate the render thread; it deletes the overflow capacity the background
work used and forces it onto the same 8 physical cores the renderer needs.

**Deliberately absent.**

- `[general]` renice / ioprio: CachyOS runs ananicy-cpp with
  cachyos-ananicy-rules, which already puts `Overwatch.exe` at nice -5 and idle
  wine services (services.exe, plugplay, explorer, tabtip) at SCHED_IDLE.
  Renice here would fight a daemon with better per-process information.
  gamemoded's ioprio pass already fails loudly and harmlessly ("Skipping ioprio
  on client: ioprio was (0) but we expected (4)"): noise, not a symptom.
- `[gpu]`: `apply_gpu_optimisations` is off by default and stays off; it needs
  accept-responsibility plus explicit clock offsets, and a bad offset is a hang.

**Why still run gamemode.** Not a no-op once pinning is off. With gamemoded
inactive the host sits at `scaling_governor=powersave` and
`energy_performance_preference=balance_performance`; while a client is
registered both go to `performance`. `park_cores=no` is the default, restated:
the two settings are independent, and parking would also need gamemode group
membership (which this user has, joined for Sunshine's RLIMIT_NICE).
