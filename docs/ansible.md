# Ansible playbook and roles

`install.yml` runs on localhost for three hosts: WSL Ubuntu (work), EndeavourOS
(BCLT, laptop), CachyOS (bcpc, desktop). Roles: `ubuntu`, `bclt`, `common`, `llm`. bcpc's host
role is `roles/bcpc` in the `iac` repo (`playbooks/bcpc.yml`, `docs/bcpc/`); this
playbook also runs `common` and `llm`, so it alone configures bcpc. Symlinked configs are live: editing the repo edits the system.

```
ansible-playbook -K install.yml                          # full
ansible-playbook -K install.yml -e config_only=true      # symlinks + system config only
```

## install.yml

- **Requires** `ansible-galaxy collection install community.general`.
- **`config_only`** drops the package-manager tasks, the brew bootstrap and the
  root certificate import. What's left is symlinking and the system configuration
  that depends on it; nothing in that path talks to a package manager, so it's
  the fast way to re-apply dotfiles. It assumes packages are installed: tasks that
  enable services still run and fail on a box that has never had a full run. Extra vars outrank play vars, hence `-e` overrides the `false` default.
- **Host detection.** `ansible_distribution` reports `Archlinux` on every Arch
  derivative with `/etc/arch-release`, so it can't tell hosts apart. `ID` in
  `/etc/os-release` doesn't help either: CachyOS ships Arch's file verbatim
  (`ID=arch`), and that check silently skipped every bcpc task it guarded. Marker
  file instead:
  - `is_eos`: `/etc/pacman.d/endeavouros-mirrorlist` (any EndeavourOS, no plain
    Arch, CachyOS or WSL).
- **Role order.** Host roles run before `common`: they own their package managers
  and common's npm task needs the npm that apt installs on Ubuntu. Each role's
  `when:` applies to every task in it, which replaced the per-task distribution
  guards.
- **`llm` last**, gated on the Arch family (both desktops, not WSL). After
  `common` because nothing in it is needed by the shared package work and
  common's full pacman upgrade is the right thing to have run before podman.

## roles/common

- Home dotfiles link via `dotfiles_dir` (`defaults/main.yml`, also in `llm`), **not**
  `ansible_env.PWD`: PWD is wherever you invoked ansible-playbook from, so running
  outside the repo produced symlinks to paths that don't exist. Not `playbook_dir`
  either: iac's `playbooks/bcpc.yml` runs `common` and `llm` by path, and its
  playbook dir is `iac/playbooks`. `realpath` normalises the `../../dotfiles`
  role path so link targets match the ones `install.yml` makes.
- `gamemode.ini` is bcpc-only, in iac's `bcpc` role. The guarded removal deletes
  the link older runs left on other hosts, but only if it points into this repo,
  so it can't undo the `bcpc` role's link when `common` runs after it.
- **Shell change**: read the login shell out of passwd first so the change is
  skipped when it already matches. The `user` module compares itself but still
  escalates, so the guard keeps a re-run from needing root. `getent_passwd` drops
  the name; index 5 is the shell; read via `ansible_facts[...]` because core 2.24
  stops providing the injected top-level name.
- **Arch package tasks live in common**, shared by bcpc and BCLT; moving them
  into iac's `bcpc` role would silently stop upgrading BCLT.
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
