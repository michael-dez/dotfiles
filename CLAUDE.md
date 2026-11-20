# dotfiles

Dotfiles and system configs for three hosts, applied by `ansible-playbook -K install.yml`
(`-e config_only=true` to skip package installs). Hosts: **bcpc** (CachyOS desktop), **BCLT**
(EndeavourOS laptop, i3), WSL Ubuntu (work). Most files are symlinked live into `~`, so a parse
error is a broken system.

bcpc-only config (its role, Hyprland, kitty, Sunshine, ollama units, OpenRGB, `/etc` files,
`zshrc.bcpc`) lives in `~/repos/iac` (`roles/bcpc`, `playbooks/bcpc.yml`,
`docs/bcpc/`). This repo keeps what bcpc shares with the other hosts.

## Comments and docs

Follow the House style in the home repo's `AGENTS.md`: one or two lines naming the mechanism, no
long headers, nothing that restates the code. This repo is public, so it has no `docs/`; design
notes and reasoning live in the private home repo. Keep hostnames, IPs, network layout and work
details out of files and commit messages. The long comment headers this repo used to have were
generated output, not the owner's style; do not read them back as house style. Do not add scripts
or tooling to the repo; keep diagnostics in the scratchpad.

Upstream-derived files (`i3/config`, `i3/scripts/`, `picom/picom.conf`, `p10k.zsh`,
`xfce4/terminal/accels.scm`) keep their original comments.
