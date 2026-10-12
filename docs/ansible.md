# Ansible playbook and roles

`install.yml` runs on localhost for three hosts: WSL Ubuntu (work), EndeavourOS
(BCLT, laptop), CachyOS (bcpc, desktop). Roles: `ubuntu`, `bcpc`, `bclt`, `common`,
`llm`. Symlinked configs are live: editing the repo edits the system.

```
ansible-playbook -K install.yml                          # full
ansible-playbook -K install.yml -e config_only=true      # symlinks + system config only
```

## install.yml

- **Requires** `ansible-galaxy collection install community.general`.
- **`config_only`** drops the package-manager tasks, the brew bootstrap and the
  root certificate import. What's left is symlinking and the system configuration
  that depends on it; nothing in that path talks to a package manager, so it's
  the fast way to re-apply dotfiles. It assumes packages are installed: the tasks
  that enable earlyoom or zram still run and fail on a box that has never had a
  full run. Extra vars outrank play vars, hence `-e` overrides the `false` default.
- **Host detection.** `ansible_distribution` reports `Archlinux` on every Arch
  derivative with `/etc/arch-release`, so it can't tell hosts apart. `ID` in
  `/etc/os-release` doesn't help either: CachyOS ships Arch's file verbatim
  (`ID=arch`), and that check silently skipped every bcpc task it guarded. Marker
  files instead:
  - `is_cachyos`: `/etc/pacman.d/cachyos-mirrorlist` (any CachyOS, no plain Arch
    or EndeavourOS).
  - `is_eos`: `/etc/pacman.d/endeavouros-mirrorlist` (any EndeavourOS, no plain
    Arch, CachyOS or WSL).
- **Role order.** Host roles run before `common`: they own their package managers
  and common's npm task needs the npm that apt installs on Ubuntu. Each role's
  `when:` applies to every task in it, which replaced the per-task `is_cachyos`
  and distribution guards.
- **`llm` last**, gated on the Arch family (both desktops, not WSL). After
  `common` because nothing in it is needed by the shared package work and
  common's full pacman upgrade is the right thing to have run before podman.

## roles/common

- Home dotfiles link via `playbook_dir`, **not** `ansible_env.PWD`: PWD is wherever
  you invoked ansible-playbook from, so running outside the repo produced
  symlinks to paths that don't exist.
- `gamemode.ini` is linked on every host. It disables `pin_cores`, which on the
  hybrid 14700KF pins the client tree to the P-cores and costs Overwatch its 12
  E-cores; harmless on non-hybrid hosts. See [system.md](system.md#gamemode).
- **Shell change**: read the login shell out of passwd first so the change is
  skipped when it already matches. The `user` module compares itself but still
  escalates, so the guard keeps a re-run from needing root. `getent_passwd` drops
  the name; index 5 is the shell; read via `ansible_facts[...]` because core 2.24
  stops providing the injected top-level name.
- **Arch package tasks live in common**, shared by bcpc and BCLT; moving them
  into `bcpc` would silently stop upgrading BCLT.
- **Per-host package manifest.** The unsuffixed `bak/pacman-export.txt` is an
  EndeavourOS X11/i3/LightDM list; installing it on bcpc would drag a second
  display manager onto a Hyprland box. `zshrc` writes
  `pacman-export-<hostname>.txt`, and only a matching one is restored.

## roles/ubuntu

- **certs.yml.** DoD root certificates, without which internal HTTPS on the work
  network fails to verify. Idempotency is in `scripts/add-dod-certs.sh`: it
  downloads the DISA bundle, stages the certificates, and compares with
  `/usr/local/share/ca-certificates` before writing, so a re-run installs nothing
  and doesn't re-run `update-ca-certificates`. Exit status, diff-style: 0 store
  already matched, 2 certs changed and store rebuilt; that's what lets the task
  avoid reporting changed on every run. The script autodetects the trust store
  from `/etc/os-release` and handles Arch too. Gated by `config_only` because it
  downloads from DISA and rewrites the system trust store.
- **config.yml (brew in bash PATH).** bash isn't the login shell but WSL drops into
  it often (`wsl.exe -e`, VS Code server, cron). The line is
  `eval "$(.../brew shellenv)"` with quoted command substitution; the old bare
  `eval /path/to/brew shellenv` evaluated the empty output of a command and set
  nothing. The regexp matches the old broken form too, so old boxes get it
  rewritten in place rather than gaining a second line. No matching task for
  `~/.zshrc`: common links it to the repo's `zshrc`, so `lineinfile` would write
  through the symlink into the tracked file, dirtying the repo each WSL run.
  `zshrc` already runs `brew shellenv` in its `[[ "$NAME" == "Ubuntu" ]]` block.

### scripts/add-dod-certs.sh: local changes

Vendored from AfroThundr's gist (v0.4.2, 2025-04-25, GPL-3.0-or-later), locally
modified. Carry these forward if it's ever refreshed from upstream:

- **Idempotent.** Upstream unconditionally rewrote every certificate and ran the
  trust-store update on each invocation, which is the slow part and made the
  Ansible task report a change forever. Certificates are now staged in the temp
  directory, normalised, compared against what's installed; only differing ones
  are written, and the update command runs only if at least one did. Expect the
  first run after this change to rewrite every certificate, because upstream left
  the `subject=` header line that `openssl pkcs7 -print_certs` emits inside each
  `.crt` and this doesn't. The run after that is a no-op.
- **Exit status follows diff(1):** 0 trust store already matched, nothing written;
  2 certificates written and trust store updated; 1 error.
- **gawk is invoked by name and checked up front.** The rename step uses
  `gensub()`, a gawk extension; on Ubuntu the default awk is mawk, so it failed at
  runtime with the download and split already done.
- **Root and trust-store writability are checked before the download**, not
  discovered after it.

## roles/bclt

Thin on purpose: nearly everything is in `common`. Exists for what's true only of
BCLT, starting with the per-host shell file (`zshrc.bclt` -> `~/.zshrc.local`),
which BCLT had no home for until the ollama forward needed one.

## roles/bcpc

Wayland desktop, Sunshine host, memory-pressure work, ollama, OpenRGB.
`main.yml` order: packages, config, ollama, OpenRGB. ollama goes after config
because the stream hooks that suspend it are symlinked there and the polkit rule
that lets them run is installed in `ollama.yml`; neither ordering breaks the
other (hooks are read at stream start) but this keeps a first run from arming a
service whose hooks aren't in place.

### packages.yml

- **`cachyos-settings` is not optional.** `system/nvidia-bcpc.conf` deliberately
  doesn't set `NVreg_InitializeSystemMemoryAllocations` so this package's
  `/usr/lib/modprobe.d/nvidia.conf` supplies 0; without it, nothing sets it and
  the driver default of 1 applies. It also carries the `30-zram.rules` udev rule
  disabling zswap (zswap in front of zram double-compresses into RAM) and the
  `swappiness=150` that `99-zram.conf` duplicates.
- **`ollama-cuda`, not `ollama`**: same version/binary plus the CUDA runtime under
  `/usr/lib/ollama`. Without it ollama silently falls back to CPU, an
  order-of-magnitude slowdown with no message. Depends on `ollama` (binary, unit,
  `ollama` user) and `cuda` (a few GB).
- **`openrgb`** carries the udev rules tagging I2C/hidraw nodes `uaccess` (no root
  needed) and a `modules-load.d` entry for `i2c-dev`; without that the DIMMs and
  GPU have no `/dev/i2c-*` node.

### defaults/main.yml: `ollama_models`

A model that doesn't fit in VRAM still runs, with overflow layers on the CPU and
roughly 10x slower generation, so fit is what to check before adding one. The
budget is smaller than the card: ollama reports the 4070 Ti as 11.6 GiB total and
10.0 GiB *available* with Hyprland up (the `inference compute` log line), and KV
cache and context come out of that on top of weights. Past ~9 GB of weights is
already spilling. Pulling is idempotent by name, but a first run downloads all of
them, about 30 GB; drop entries here rather than editing the task.

| model | size | why |
|---|---|---|
| `qwen3:14b` | ~9 GB | general default; fits with room for long context; only one with real reasoning |
| `gpt-oss:20b` | ~13 GB (MXFP4) | does NOT fit; a few layers on CPU, noticeably slower; strongest the host can run |
| `llama3.1:8b` | ~4.9 GB | small, fast, leaves the card mostly free for when something else uses the GPU |
| `qwen2.5-coder:7b` | ~4.7 GB | fill-in-the-middle for editor plugins, which want milliseconds over cleverness |

### config.yml

- **Superseded symlinks removed.** `file` with `with_items` creates only what's
  listed and has no notion of items that used to exist. The explicit `absent`
  task stops an older `install.yml` run leaving dangling `hyprland.conf` symlinks
  beside the Lua ones; Hyprland would have two plausible configs to choose from.
- **Hyprland config is Lua** (upstream deprecated hyprlang in 0.55). Each file is
  a separate `require()` scope, so an error in one doesn't take down the rest.
- **`kitty/colors.conf`** is a static Iceberg export `kitty.conf` includes by a
  path relative to `~/.config/kitty`, so it's linked alongside. It's the
  pre-Noctalia fallback; the generated `themes/noctalia.conf` included after it
  wins once Noctalia has applied its templates. Not linking it is only a kitty
  warning. See `kitty/kitty.conf` for ordering.
- **Sunshine files are symlinked** because Sunshine rewrites `sunshine.conf` and
  `apps.json` from its Web UI; linking makes those edits show in `git status`
  instead of drifting. `sunshine_state.json` and `credentials/` are deliberately
  not linked: they hold the Web UI password hash and paired-client certificates
  and this repo is published.
- **`stream-mode.sh`** is called by `stream-start.sh` and again by the "Desktop"
  app's own prep-cmd in `apps.json`, so it's linked whether or not the Hyprland
  hooks are in use. `desktop-audio.sh` is only called by it.
- **ollama hooks** are the second `global_prep_cmd` pair. Separate scripts rather
  than lines in `stream-start.sh`, which bails when no Hyprland is live, and
  freeing the GPU shouldn't depend on the compositor. See [llm.md](llm.md#stream-hooks).
- **Noctalia** keeps config under `~/.local/state/noctalia`, not `~/.config`
  (`~/.config/noctalia` also gets created and stays empty), so it can't ride on
  common's XDG task. `settings.toml` is the only hand-authored file there;
  Noctalia rewrites it on every settings change via atomic replace, which is safe
  to link: it resolves the symlink first and renames the new file over the
  target in the repo, so the link survives and GUI changes land in `git status`
  (new inode each time; irrelevant to git). Nothing else there is config:
  `clipboard/` is encrypted history, `notification_history.json` a log,
  `community-palettes/`/`community-templates/` re-downloadable caches,
  `state.toml` credential-migration flags. Not for a published repo.
- **Custom palettes** live in `~/.config/noctalia/palettes/` (hence that directory
  exists). `Iceberg.json` is the source of truth for the machine's colours:
  Noctalia renders it into every enabled template on theme change; `settings.toml`
  enables the built-in kitty template under `[theme.templates]`, writing
  `~/.config/kitty/themes/noctalia.conf`. Edit it and re-apply to change the
  scheme everywhere.
- **`gamemode` group.** Sunshine logs "setpriority failed for nice -15: Permission
  denied" on every stream because `RLIMIT_NICE` is 0 for ordinary users, so it
  can't raise capture/encode thread priority, showing as frame-pacing jitter
  under load. CachyOS ships `/etc/security/limits.d/10-gamemode.conf` granting
  `@gamemode - nice -10`; joining the group is the whole fix (effective at next
  login).
- **Sunshine OOMPolicy drop-in** (`sunshine/systemd/oom.conf`): when Sunshine
  starts Steam, what Steam launches inherits Sunshine's cgroup, and systemd's
  default `OOMPolicy=stop` means one OOM-killed descendant stops the unit. A user
  unit, symlinked like the rest of `~/.config`.
- **Memory-pressure files are copied, not symlinked**, the one departure from the
  symlink convention. `/etc/systemd/zram-generator.conf` is consumed by a
  generator in early boot and the sysctl drop-ins by `systemd-sysctl.service`,
  both before `/home` (a separate btrfs subvolume) is mounted; a symlink into
  `~/repos/dotfiles` would resolve to nothing. Same for `uinput.conf`
  (`systemd-modules-load`). Background: bcpc was built by hand, never got
  cachyos-settings or its zram, and ran swapless; a runaway allocation there
  puts the kernel in a reclaim livelock where the only thing left to evict is
  executable text. Rationale per file in [system.md](system.md).
- `copy` doesn't create parent directories, so the earlyoom drop-in directory is
  created explicitly.
- **Old `/etc/modprobe.d/nvidia.conf` removal.** Hand-written at install, owned by
  no package (`pacman -Qo` says so), so nothing will clean it up. Left in place it
  keeps its exact-name collision with cachyos-settings and suppresses the
  distro's NVIDIA defaults, including `InitializeSystemMemoryAllocations=0`.
  `copy` writes the new name but has no opinion about the old one.
- **Initramfs rebuild: a reboot alone is not enough.** `/etc/mkinitcpio.conf` has
  `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`, so nvidia loads from
  the initramfs before the real root, and the `modconf` hook bakes a *copy* of
  `/etc/modprobe.d` and `/usr/lib/modprobe.d` into the image. Until rebuilt, the
  files on disk aren't what the module reads. Observed once: the first run
  installed cachyos-settings (its pacman hook rebuilt the initramfs at 11:33),
  then removed the colliding `nvidia.conf` at 11:39, so the image captured
  mid-migration with the old file still shadowing; the 11:41 reboot booted that,
  `/proc/driver/nvidia/params` showed `InitializeSystemMemoryAllocations: 1`, and
  every file on disk looked right. Oracle: `lsinitcpio <img> | grep modprobe`.
  The gate (`mem_conf` or stale nvidia.conf changed) is deliberately broader than
  needed: a redundant rebuild costs minutes, a missed one costs a config that
  looks applied and is inert. After reboot verify `grep
  InitializeSystemMemoryAllocations /proc/driver/nvidia/params` shows 0.
- `uinput.conf` is kept out of `mem_conf`: a modules-load.d file needs no
  initramfs rebuild.
- **earlyoom** is `daemon_reload` + `restarted` (not `started`) because the
  arguments are on the `ExecStart` line and a running instance would keep the old
  ones.
- **zram** is a generator, not a daemon: it synthesises
  `systemd-zram-setup@zram0.service` from the config in early boot; `daemon_reload`
  re-runs generators, making the device available without a reboot.

### openrgb.yml

All per-user and symlinked: the units only run inside a login session, after
`/home` is mounted. File-level detail in [rgb.md](rgb.md).

- **Detectors off** (`openrgb_detectors_off` in defaults). Adding a name there and
  re-running is the whole procedure; names are exactly as `OpenRGB.json` lists
  them.
  - `Logitech HID++ 2.0` claims the PRO X 2 DEX, which has no LEDs: it reports 214
    single-LED zones named after bytes of the device's own ID and keeps a watcher
    open on the receiver. That receiver is the one solaar holds the mouse's DPI
    through (`hypr/bcpc.lua`), and the same driver has a path switching onboard
    profiles into host mode, exactly what solaar is there to own. Measured: with
    it off, OpenRGB never opens the receiver.
  - `Wooting 60HE+`: switches have no LED window, nothing to light, and OpenRGB
    taking the Wooting's RGB interface is reported to clash with some Wooting
    settings. Off rather than merely omitted from the gradient: a detected
    keyboard is still put in Direct mode by the saved profile on every server
    start.
- **`OpenRGB.json` isn't symlinked.** OpenRGB writes the whole file back with all
  ~1900 detectors, so a linked copy churns `git status` on every GUI change. It
  *merges* a partial file on load, so creating one holding only these keys on a
  fresh box is safe (measured against a scratch `--config` directory).
- A running OpenRGB overwrites the file from memory on its next settings save,
  which would put the detectors back. So: check first, stop the units only if an
  edit is due, then edit.
- **The Iceberg profile** is the static profile the server loads at start. Made
  once with the daemon not yet running, because the save captures whatever the
  server shows at that instant and the daemon repaints 20x/s. Remake after
  changing palette or layout:

  ```
  systemctl --user stop iceberg-rgb
  rm ~/.config/OpenRGB/profiles/Iceberg.json && iceberg-rgb --save-profile Iceberg
  systemctl --user start iceberg-rgb
  ```

  Not in the repo: it records each device's serial and location, the DualSense's
  Bluetooth MAC among them; the repo is published.
- Restart the **server**, not the daemon, after a unit change: an edited unit
  needs the server restart, and on first run it must come up with the profile just
  saved. Restarting it takes the daemon down (`BindsTo`); the next task brings it
  back. Restarting only the daemon wouldn't reach the server (`BindsTo` propagates
  stops from the server, not restarts to it).
- Starting the gradient assumes the playbook runs from the desktop session (device
  access needs one; see `openrgb-server.service`). From next login
  `hypr/bcpc.lua` starts it.
