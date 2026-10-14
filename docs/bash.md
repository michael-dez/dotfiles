# Bash (`bash/`)

Portable bash config for machines that don't get the zsh setup, including git-bash on
Windows. Bash 4.4+, no dependencies beyond coreutils and the tools themselves.

Install: copy or clone `bash/` anywhere, then add to `~/.bashrc`:

```bash
. ~/bash/bashrc
```

`bashrc` sources `bashrc.d/*.sh` in name order. Each tool file returns early when its
tool isn't on `PATH`, so the same directory works on every machine.

## core

`_have` tests for a command. `_pick` reads lines on stdin and prints the chosen one:
it returns a lone line directly, uses fzf when present, and falls back to a numbered
`select` menu.

Vi line editing (`set -o vi`; `v` in command mode opens `$EDITOR`). `sbashrc` re-sources
`~/.bashrc`, like `szshrc`.

## history

Set up for turning sessions into scripts later.

- `ignoreboth`: drops consecutive duplicates only, so the order of commands survives.
  `erasedups` would delete earlier copies and break the sequence. A command with a
  leading space isn't saved, which keeps secrets out.
- `history -a` runs at every prompt, so a dropped SSH session doesn't lose its history.
- `lithist` keeps multi-line commands as written.
- The file stores epoch timestamps. The `history` wrapper shows them in UTC
  (`%FT%TZ`), whatever the machine's timezone is.

## az

| command | does |
|---|---|
| `azw` | current subscription, user, tenant, cloud |
| `azl [mi\|dc] [args]` | `az login` via managed identity or device code; extra args go to `az login` |
| `azs [pattern]` | pick a subscription (case-insensitive filter), set it, export `ARM_SUBSCRIPTION_ID` |
| `azc [name]` | list clouds, or switch (log in again afterwards) |
| `azenv` | export `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_ENVIRONMENT` from the az context |
| `azrg [pattern]` | resource groups, filtered |
| `azr [rg]` | resources in a group; picks the group if omitted |
| `azvm [rg]` | VMs with power state and IPs |

`azl` with no mode uses managed identity when `ARM_CLIENT_ID` is set, else device code.
Newer az replaced `--username` with `--client-id` for user-assigned identities; `azl`
checks `az login --help` and uses whichever the installed version has.

`azenv` leaves auth variables alone so terraform keeps using the az login.

Filters run on the table output rather than in `--query`, because JMESPath `contains`
is case-sensitive.

## git-bash

- MSYS converts arguments that look like absolute paths, which mangles resource IDs
  (`/subscriptions/...`). `az` is wrapped with `MSYS_NO_PATHCONV=1`.
- az on Windows ends tsv lines with CRLF; `_az_tsv` strips the `\r` so captured IDs
  are usable.

## git

Same alias names as `zshrc` (`gs`, `ga`, `gc`, `ghm`) plus `gd`, `gco`, `gl`.

## terraform

`tf` alias with terraform's own completion (`complete -C`). `tfp` writes `tfplan`,
`tfa` applies it (flags go before the plan file). `tfw` lists workspaces, or selects
one. `TF_PLUGIN_CACHE_DIR` defaults to `~/.terraform.d/plugin-cache`.

## packer

`pk` alias with completion. `pki`, `pkv` (fmt + validate), `pkb` (build with
timestamps) act on the current directory; arguments are passed before the `.`.
