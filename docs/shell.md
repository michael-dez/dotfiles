# Shell (`zshrc`, `zshrc.bclt`)

`zshrc` is linked to `~/.zshrc` on every host; the per-host file is linked to
`~/.zshrc.local` and sourced at the end. The installer picks it by marker file
(see [ansible.md](ansible.md#installyml)), so the name is fixed rather than
`$(uname -n)`: WSL-on-bcpc reports `BCPC` and CachyOS-on-bcpc `bcpc`, differing
only by case and colliding on a case-insensitive checkout. Host-specific addresses
and mount points live in untracked `~/.zshrc.private` because this repo is
published. bcpc's `zshrc.bcpc` is in the `iac` repo (`docs/bcpc/shell.md`).
For `ollama-forward` see [llm.md](llm.md#bclt-forward).

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
