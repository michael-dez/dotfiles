# dotfiles

Dotfiles and system configs for three hosts, applied by `ansible-playbook -K install.yml`
(`-e config_only=true` to skip package installs). Hosts: **bcpc** (CachyOS desktop, Hyprland,
Sunshine, ollama), **BCLT** (EndeavourOS laptop, i3), WSL Ubuntu (work). Most files are symlinked
live into `~`, so a parse error is a broken system; `/etc` files are copied (read before `/home`
mounts) and need a playbook run to take effect.

## Comments in config files

Config files get one or two lines naming the mechanism, plus `Why: docs/<file>.md#<section>`.
Reasoning goes in `docs/`, not inline. The long comment headers this repo used to have were
generated output, not the owner's style; do not read them back as house style. Do not add scripts
or tooling to the repo; keep diagnostics in the scratchpad.

## Docs

| file | covers |
|---|---|
| [docs/system.md](docs/system.md) | earlyoom, sysrq, zram, `nvidia-bcpc.conf` (filename must not be `nvidia.conf`), uinput, gamemode (`pin_cores=no`) |
| [docs/llm.md](docs/llm.md) | ollama socket/proxy/override/polkit (loopback only), stream hooks, containers (no `[Install]`), `roles/llm` |
| [docs/streaming.md](docs/streaming.md) | `sunshine/`, hooks, pipewire sink, `hypr/stream.lua` (operations guide: `sunshine/README.md`) |
| [docs/hyprland.md](docs/hyprland.md) | `hypr/*.lua`, kitty |
| [docs/rgb.md](docs/rgb.md) | OpenRGB server, `iceberg-rgb` |
| [docs/ansible.md](docs/ansible.md) | `install.yml`, roles, cert script |
| [docs/shell.md](docs/shell.md) | zshrc and per-host files |
| [docs/i3.md](docs/i3.md) | i3 passthrough mode (BCLT) |
| [docs/known-issues.md](docs/known-issues.md) | unsolved problems |

Upstream-derived files (`i3/config`, `i3/scripts/`, `picom/picom.conf`, `p10k.zsh`,
`xfce4/terminal/accels.scm`) keep their original comments.
