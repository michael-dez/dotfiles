# dotfiles

Dotfiles and system configs for three hosts, applied by `ansible-playbook -K install.yml`
(`-e config_only=true` to skip package installs). Hosts: **bcpc** (CachyOS desktop), **BCLT**
(EndeavourOS laptop, i3), WSL Ubuntu (work). Most files are symlinked live into `~`, so a parse
error is a broken system.

bcpc-only config (its role, Hyprland, kitty, Sunshine, ollama units, OpenRGB, `/etc` files,
`zshrc.bcpc`, and their docs) lives in `~/repos/iac` (`roles/bcpc`, `playbooks/bcpc.yml`,
`docs/bcpc/`). This repo keeps what bcpc shares with the other hosts.

## Comments in config files

Config files get one or two lines naming the mechanism, plus `Why: docs/<file>.md#<section>`.
Reasoning goes in `docs/`, not inline. The long comment headers this repo used to have were
generated output, not the owner's style; do not read them back as house style. Do not add scripts
or tooling to the repo; keep diagnostics in the scratchpad.

## Docs

| file | covers |
|---|---|
| [docs/llm.md](docs/llm.md) | containers (no `[Install]`), `roles/llm`, BCLT ollama forward |
| [docs/ansible.md](docs/ansible.md) | `install.yml`, roles, cert script |
| [docs/shell.md](docs/shell.md) | zshrc and per-host files |
| [docs/i3.md](docs/i3.md) | i3 passthrough mode (BCLT) |
| [docs/bash.md](docs/bash.md) | portable `bash/` config (az, terraform, packer, git-bash) |

Upstream-derived files (`i3/config`, `i3/scripts/`, `picom/picom.conf`, `p10k.zsh`,
`xfce4/terminal/accels.scm`) keep their original comments.
