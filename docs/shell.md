# Shell (`zshrc`, `zshrc.bcpc`, `zshrc.bclt`)

`zshrc` is linked to `~/.zshrc` on every host; the per-host file is linked to
`~/.zshrc.local` and sourced at the end. The installer picks it by marker file
(see [ansible.md](ansible.md#installyml)), so the name is fixed rather than
`$(uname -n)`: WSL-on-bcpc reports `BCPC` and CachyOS-on-bcpc `bcpc`, differing
only by case and colliding on a case-insensitive checkout. Host-specific addresses
and mount points live in untracked `~/.zshrc.private` because this repo is
published. For `ollama-forward` see [llm.md](llm.md#bclt-forward).

## zshrc

- **Keymap on X11 only.** Under Wayland the compositor owns the layout (Hyprland
  `kb_options`, `hypr/bcpc.lua`). `xorg-xwayland` pulls in `setxkbmap`, so the
  command test alone isn't enough; `$WAYLAND_DISPLAY` is checked too.
- **Package manifests** (Arch family, `pacman-export-<host>.txt` etc. in `bak/`) are
  keyed on `ID`/`ID_LIKE`, not `NAME`: BCLT reports `NAME="EndeavourOS"` (not
  "EndeavourOS Linux"), so the old `NAME` test never matched and the exports hadn't
  run since 2025-08. `ID_LIKE=arch` also covers CachyOS. Per-host filenames so bcpc
  and BCLT don't overwrite each other; refreshed at most once a day, not every
  shell startup.

## zshrc.bcpc

- Interactive-shell scope only. Session-wide env (Wayland, NVIDIA, toolkits) lives
  in `hypr/bcpc.lua` because GUI apps launched from the Noctalia launcher never
  source `~/.zshrc`.
- **gamescope aliases are `gs-*`, not `gs`** (`gs` is `git status` in zshrc).
  Monitor modes, confirmed live via `hyprctl monitors`: DP-3 BenQ ZOWIE XL2586X
  1920x1080@539.56 (left); DP-1 Alienware AW3425DWM 3440x1440@179.99 (right).
  `-O`/`--prefer-output` only takes effect on the DRM backend (a standalone
  gamescope session). Nested in Hyprland, gamescope is just another window and
  Hyprland decides where it lands; workspace 1 is bound to DP-3, so launching from
  workspace 1 puts it on the fast panel. `-O` is harmless either way.
- Steam per-game launch options for the 540 Hz panel:
  `gamescope -W 1920 -H 1080 -r 540 -O DP-3,DP-1 -f -- %command%`
