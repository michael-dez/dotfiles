# Local LLM stack (ollama, Open WebUI, Langflow)

## Design

- ollama runs only on bcpc, only on loopback, started on demand by a socket.
  Its units, polkit rule and stream hooks are in the `iac` repo
  (`roles/bcpc`, `docs/bcpc/ollama.md`).
- Open WebUI and Langflow run as rootless podman quadlets on **each** machine
  against that machine's own `127.0.0.1:11434`. On BCLT that address is an
  `ssh -L` forward to bcpc (`ollama-forward` in `zshrc.bclt`).
- So `containers/*.container` are byte-identical on both machines and nothing in
  the stack is reachable from off-box. Not run once in the k3s cluster because a
  pod on another host can't reach a loopback-only ollama without a tunnel or a
  wider bind.
- `roles/llm` is gated on the Arch family in `install.yml`: bcpc and BCLT, not
  the WSL Ubuntu work box.

## Containers

`containers/open-webui.container`, `containers/langflow.container` ->
`~/.config/containers/systemd/` (symlinked)

**Quadlet, not a hand-written unit**: podman's generator makes `<name>.service`
at daemon-reload. Start with `systemctl --user start open-webui` / `langflow`.
They're meant to be up while in use and gone otherwise, which keeps ollama's
on-demand activation meaningful.

**No `[Install]` section, on purpose.** `[Install] WantedBy=default.target` makes
the quadlet generator emit
`/run/user/1000/systemd/generator/default.target.wants/<name>.service` at every
daemon-reload, so the container starts at login. Nothing in `roles/llm` ever
called `systemctl --user enable`; the line was the whole mechanism. Cost, both
observed: open-webui had been up 19 hours holding ~230 MB resident and 517 MB
swap on a machine whose binding constraint is memory while a game is up; and
langflow, with `Restart=on-failure` and a container exiting non-zero, ran 217
restarts in a six-hour session (each a docker.io registry check, container create
and overlayfs mount, during a game). `Restart=on-failure` stays: right for a
container started on purpose, hazardous only when it starts itself at login and
fails unattended. `start` is unaffected.

ollama is the exception: `ollama.socket` stays enabled at boot (see
`iac` `docs/bcpc/ollama.md#ollamasocket`).

**`Network=host`.** ollama listens on the host's loopback; a rootless container
in its own netns has its own 127.0.0.1. Reaching a loopback-bound host service
from a bridged rootless container means `host.containers.internal` plus
pasta/slirp options that vary by podman version and fail confusingly. Host netns
makes `127.0.0.1:11434` mean what it says and drops pasta/slirp4netns entirely.

**The cost, and the guard.** The container binds host ports directly, so only the
`HOST` variable stops it listening on 0.0.0.0, and bcpc has no firewall. Hence
`HOST=127.0.0.1` / `PORT=8080` (open-webui, read by the image's `start.sh` and
passed to uvicorn; default 0.0.0.0:8080) and `LANGFLOW_HOST=127.0.0.1` /
`LANGFLOW_PORT=7860` (default 0.0.0.0:7860) are explicit, and `roles/llm` asserts
they survived into the generated unit (see [roles/llm](#rolesllm-ansible)).
Confirm the live listener once started: `ss -lnt | grep 8080` must show
`127.0.0.1:8080`, never `0.0.0.0:8080`.

**`PodmanArgs=--oom-score-adj=450`** (both). Puts them into earlyoom's ranking
without naming a process; why 450 and why not a regex: see
`iac` `docs/bcpc/system.md#earlyoom`. open-webui's comm is `python3` (identical to the
Proton launcher); langflow does rename itself, but `AutoUpdate=registry` on
`:latest` means the name isn't a stable interface and `oom_score_adj` is.

**`AutoUpdate=registry`.** Updates on next start when the tag has moved.
`podman auto-update` only acts if its timer is enabled, which nothing here does:
`systemctl --user enable --now podman-auto-update.timer`.

**open-webui specifics.**

- Data: `Volume=%h/.local/share/open-webui:/app/backend/data`. A host directory
  so it's visible, backup-able, greppable; rootless podman maps container root
  to your uid.
- **Don't set `WEBUI_AUTH=False`.** Tempting for a loopback-only UI, but Open
  WebUI treats it as one-way: an instance created with auth off can't go back to
  multi-user without wiping the data dir. Signing up once per machine is cheaper.
- `TimeoutStartSec=900`: first start pulls ~1 GB if not local. The playbook
  pre-pulls, but a hand-started container on a fresh box shouldn't be killed
  mid-download.

**langflow specifics.**

- `LANGFLOW_CONFIG_DIR=/var/lib/langflow` with
  `Volume=%h/.local/share/langflow:/var/lib/langflow`: flows, the SQLite DB and
  cached components live on the mount, not the image's `~/.langflow`, so a
  `podman rm` takes nothing of value.
- `TimeoutStartSec=1800`: the larger pull of the two. First run also initialises
  SQLite before the UI answers; `start` returning isn't readiness. Give it a
  minute and watch `podman logs -f langflow`.
- In a flow's Ollama component the base URL is `http://127.0.0.1:11434`, same as
  the UI on either machine.

## roles/llm (ansible)

- **packages.yml.** Every quadlet is `Network=host`, so no user-mode network
  stack: neither passt/pasta nor slirp4netns is a hard requirement. podman brings
  crun and needs `newuidmap`/`newgidmap` from shadow (already on Arch).
- **subuid/subgid.** Rootless podman needs a delegated id range in both
  `/etc/subuid` and `/etc/subgid`, or it refuses to start with a `newuidmap`
  error that doesn't point here. Arch's shadow ships the files unpopulated and
  `useradd` only allocates a range when it creates the account, which for
  hand-built bcpc it never did. `100000:65536` is the conventional first range.
  The regexp anchors on the username so re-runs update instead of appending.
- **`podman system migrate`** after a range change: podman caches the mapping in
  its storage, and containers created under the old one break ("there might not
  be enough IDs available in the namespace") without the error mentioning that.
  Harmless on a first run.
- **Data dirs** are created by the playbook because podman would otherwise create
  them owned by root's mapped uid, recoverable but confusing.
- **Quadlets are symlinked** like every other user config, so repo edits are live
  after `daemon-reload` rather than a playbook run.
- **Re-run generators unconditionally**: quadlet *contents* can change without the
  symlink changing.
- **The read-back assertion** proves the generator followed the symlinks (a
  quadlet it ignores yields no unit and no error) and that the bind address
  survived. It reads `ExecStart`, **not** `Environment`: quadlet turns each
  `Environment=` line into a `--env` argument on the podman command line, and the
  only thing in the unit's own environment is `PODMAN_SYSTEMD_UNIT`. Don't use
  `systemctl --user cat` either: quadlet copies the source file's comments into
  the generated unit, so grepping it would match a comment. The parsed `ExecStart`
  property can't be fooled. The `--env ` prefix in the assertion is load-bearing:
  without it `HOST=127.0.0.1` is a substring of `LANGFLOW_HOST=127.0.0.1`.
- **Images** are pre-pulled so the first start isn't a multi-GB download behind a
  start timeout; on the far side of the `config_only` line for the same reason as
  the model pulls. Names are read out of the quadlets with `awk` so the tag is
  declared once.

## BCLT forward

`ollama-forward` alias in `zshrc.bclt`:
`ssh -N -L 11434:127.0.0.1:11434 ${BCPC_SSH_HOST:-bcpc}`.

Puts bcpc's ollama on BCLT's `127.0.0.1:11434`, the address the quadlets already
use. The remote side of `-L` resolves *on bcpc*, so on-demand activation works
through the tunnel. Foreground by default (Ctrl-C ends it); add `-f` to
background it. Host-specific addresses (`BCPC_SSH_HOST`) go in untracked
`~/.zshrc.private` because this repo is published. Both UIs need the forward up
first on BCLT.
