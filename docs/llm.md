# Local LLM stack (ollama, Open WebUI, Langflow)

## Design

- ollama runs only on bcpc, only on loopback, started on demand by a socket.
- Open WebUI and Langflow run as rootless podman quadlets on **each** machine
  against that machine's own `127.0.0.1:11434`. On BCLT that address is an
  `ssh -L` forward to bcpc (`ollama-forward` in `zshrc.bclt`).
- So `containers/*.container` are byte-identical on both machines and nothing in
  the stack is reachable from off-box. Not run once in the k3s cluster because a
  pod on another host can't reach a loopback-only ollama without a tunnel or a
  wider bind.
- `roles/llm` is gated on the Arch family in `install.yml`: bcpc and BCLT, not
  the WSL Ubuntu work box.

## ollama.socket

`system/ollama.socket` -> `/etc/systemd/system/ollama.socket`

**Why a socket + proxy.** ollama has no socket-activation support: the binary
has no reference to `LISTEN_FDS`, `LISTEN_PID` or `sd_listen_fds` (`strings
/usr/bin/ollama | grep -i listen_fds` is empty on 0.33.3), so it always `bind()`s
itself. Activation therefore goes through `systemd-socket-proxyd`: the socket
holds 11434, `ollama-proxy.service` forwards to ollama's own port 11435.

**Why on demand.** ollama idles at a few hundred MB and no VRAM, so the saving is
small; the point is that nothing is listening and no model can be loaded until
something asks. On a host that is also a game streamer, that's the difference
between "the GPU is free unless I'm using the LLM" and "...unless something ever
touched the LLM".

**Why loopback only.** ollama has no authentication of any kind. Anything that
can open the port can list, pull, delete and run models and read
`/var/lib/ollama`. bcpc runs no firewall (firewalld, ufw and nftables all
inactive), so the bind address is the only thing between this and the LAN.
Widening it is a one-line change but hands the whole LAN an unauthenticated API.
Clients are arranged to make loopback workable: the containers use
`Network=host`, and BCLT uses the ssh forward. Nothing reaches ollama from
off-box without authenticating to sshd first.

**Both families.** `ListenStream=127.0.0.1:11434` and `[::1]:11434`. A client
connecting to the name `localhost` gets `::1` first from getaddrinfo on this
host; a v4-only bind would refuse it while `curl 127.0.0.1:11434` worked. Verified
with `systemd-socket-activate` on exactly those two addresses, reaching ollama
via `127.0.0.1`, `[::1]` and `localhost`.

**`Service=ollama-proxy.service`** is required because the socket name doesn't
match the service it triggers; otherwise systemd looks for `ollama.service` and
hands the descriptor to a process that can't use it.

**`[Install]` kept on purpose.** The socket stays enabled at boot while both UIs
are not. It holds a loopback port and starts nothing; with no client running at
login nothing connects and ollama stays down. "Nothing listening until asked" is
met by leaving `ollama.service` disabled (`roles/bcpc/tasks/ollama.yml`), not by
disarming the socket. Armed is also what lets the `ollama` CLI and the
playbook's model tasks reach 127.0.0.1:11434 without a manual start.

## ollama-proxy.service

`system/ollama-proxy.service` -> `/etc/systemd/system/ollama-proxy.service`

Started by the socket on first connection; forwards to `127.0.0.1:11435`.

- **`BindsTo=ollama.service`, not `Requires=`.** If ollama goes away (crash, or
  the stream hook stopping it) the proxy must go too rather than accept
  connections it can only refuse. Stopping it re-arms `ollama.socket`, so the
  next request starts the pair again. With `Requires=` the proxy survives a dead
  backend and the socket stays "running", which looks identical from outside and
  fails every request.
- **`After=ollama.service`** waits on ollama's `ExecStartPost` readiness gate (see
  below). Without it the proxy would connect to an unbound port and the
  connection that triggered activation would be the one to fail.
- **Hardening.** The proxy needs only the inherited fd and a loopback connect, so
  it gets nothing else, and runs as `ollama` rather than root like
  `ollama.service`.
- The proxy splices in userspace; throughput is irrelevant (responses are tokens)
  and latency is well under time-to-first-token. Model pulls go through it and
  it keeps up with the disk.

## ollama-override.conf

`system/ollama-override.conf` -> `/etc/systemd/system/ollama.service.d/override.conf`

A drop-in because pacman owns and rewrites `/usr/lib/systemd/system/ollama.service`
on every upgrade. `User=ollama`, `OLLAMA_MODELS=/var/lib/ollama`,
`ProtectSystem=full`, `Restart=on-failure` are inherited untouched.

- **`OLLAMA_HOST=127.0.0.1:11435`**: the socket owns 11434, so ollama moves to
  11435. Both loopback-only. 11434 is the port every client assumes.
- **`OLLAMA_MAX_LOADED_MODELS=1`**: about a 12 GB card. The default loads a second
  model beside the first whenever ollama thinks VRAM fits, computed against a
  free-VRAM figure that doesn't know a game is about to want 8 GB.
- **`OLLAMA_KEEP_ALIVE=5m`**: ollama's default, restated because it's load-bearing
  here and shouldn't change silently on upgrade; it is what returns VRAM without
  anyone asking. For "5m is too long" (a stream starting now) see
  [stream hooks](#stream-hooks).
- **`OOMScoreAdjust=200`**: earlyoom ranks on `/proc/*/oom_score`, which folds in
  adj, so one number makes ollama a preferred victim for earlyoom and the kernel
  alike without naming it in `--prefer`. A killed ollama costs a re-run prompt;
  the desktop or Sunshine losing the same fight costs the session. Positive adj
  needs no privilege and can't be reverted by the process.
- **`ExecStartPost` readiness gate.** The packaged unit is `Type=simple`, so it's
  "active" the instant `fork()` returns, seconds before HTTP is up; each of those
  seconds is a window where the proxy forwards into a closed port.
  `ExecStartPost` is part of the start job, so `After=ollama.service` doesn't
  complete until it does. Written with **no `$`**: systemd expands `$NAME` on
  `ExecStart` lines, so a shell loop variable would be substituted to nothing
  before bash saw it. `until` needs no counter; the bound is `TimeoutStartSec=60`
  (which counts `ExecStartPost` too): if ollama hasn't answered in 60s, fail
  loudly rather than hang.

## Polkit rule

`system/49-ollama-stream.rules` -> `/etc/polkit-1/rules.d/49-ollama-stream.rules`

The Sunshine hooks run as mike from Sunshine's systemd *user* service, but the
units to stop are *system* units. Without a rule systemctl falls back to asking
polkit interactively with no agent to answer, so the call fails and the stream
starts with ollama still holding VRAM, silently (hooks are best-effort).

Scoped three ways, since "systemctl without a password" is a bigger grant than
needed:

- to `wheel`, who can already sudo, so this adds no authority; only removes the
  prompt for these units;
- to the three units by exact name (a prefix/regex would cover future units);
- to start/stop/restart only, not enable/disable/mask: whether ollama returns
  after reboot is the playbook's decision, and a hook that could mask a unit
  could disable it permanently by accident.

Group membership, not a hardcoded `mike`, so no templating is needed and it
grants nothing where the account was never an admin.

polkitd watches the directory with inotify; no reload needed. A syntax error is
logged and the file skipped, which looks identical to a rule that didn't match:
check `journalctl -u polkit -n 20` after any edit.

## Stream hooks

`sunshine/hooks/ollama-suspend.sh` / `ollama-resume.sh`

Sunshine prep "do"/"undo" pair, independent of the Hyprland hooks. Separate from
`stream-start.sh` because that sources `hyprctl-env.sh`, which exits 0 when no
live Hyprland is found; anything appended there would be silently skipped
exactly when it still matters (a stream with the compositor dead).

**suspend.** Stops the service instead of waiting for keep-alive: the game wants
VRAM now. `ollama.socket` is stopped too, otherwise anything touching the API
restarts the chain; desktop LLM clients poll `/api/tags` on their own. Order:
socket first so nothing re-triggers activation in the gap, then the proxy and
ollama (the proxy would follow via `BindsTo`, but naming it survives that
dependency being loosened). `timeout 20` because this is on the critical path of
a client connecting and a wedged unit would otherwise delay the stream by the
90s default. A failure is most likely the polkit rule missing; the visible
symptom is just a game with less VRAM.

**Flag file.** Suspend writes `$XDG_RUNTIME_DIR/ollama-was-up` before stopping
anything; resume reads it, so a stream can't *start* ollama on a machine where
it was deliberately stopped. Runtime dir, not state: per-boot, and a stale flag
surviving a reboot is worse than none.

**resume.** Starts `ollama.socket` and nothing else; the first request brings
the rest up. Starting `ollama.service` would leave it running for the rest of
the boot regardless of use. Also runs when a client vanishes uncleanly, so it
must tolerate suspend never having run.

`hook_log` duplicates `hyprctl-env.sh`'s format (one interleaved log) but isn't
sourced from it, because sourcing imports its bail-on-no-compositor behaviour.
Both hooks always `exit 0`: a stream must never fail because a background service
wouldn't stop.

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
[above](#ollamasocket)).

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
[system.md](system.md#earlyoom). open-webui's comm is `python3` (identical to the
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

## roles/bcpc ollama.yml

- Copied into `/etc`, not symlinked from the repo: systemd and polkitd read these
  at boot before `/home` is mounted, so a symlink into `~/repos/dotfiles` would
  resolve to nothing at the wrong moment. Sunshine hooks are symlinked like the
  rest of `~/.config`; they only run once a session exists.
- Polkit rules dir: no owner/group/mode on purpose. polkit ships it
  `root:polkitd 0750`; setting attributes would fight or widen that. polkitd
  reads rules as root and refuses group/world-writable, hence file mode `0644`.
- `state: stopped`, not `restarted`, for ollama after a change: the settings live
  in the env of a process that may not be running, and starting one defeats
  on-demand activation. The next activation picks up the drop-in.
- The socket is **restarted** (not started) on change: a socket binds at start and
  would keep serving the old `ListenStream`. This also re-arms it after the stop.
- `ollama.service` is explicitly **not** enabled: an enabled service races the
  socket for 11434 (winning when nothing wants inference, losing noisily
  otherwise). The packaged unit ships disabled; this only matters if someone ran
  `systemctl enable ollama` by hand.
- **Models** are past the `config_only` line (tens of GB). They talk to
  `127.0.0.1:11434` as an ordinary unprivileged client; files land in
  `/var/lib/ollama` because the server writes them. `ollama list` also proves the
  chain end to end (socket -> proxy -> readiness gate). Pulls are skipped if the
  name is in `ollama list` (idempotent anyway, but this keeps re-runs silent and
  offline); the substring match is on the NAME column, so every `ollama_models`
  entry must be tagged (`qwen3:14b`).

## BCLT forward

`ollama-forward` alias in `zshrc.bclt`:
`ssh -N -L 11434:127.0.0.1:11434 ${BCPC_SSH_HOST:-bcpc}`.

Puts bcpc's ollama on BCLT's `127.0.0.1:11434`, the address the quadlets already
use. The remote side of `-L` resolves *on bcpc*, so on-demand activation works
through the tunnel. Foreground by default (Ctrl-C ends it); add `-f` to
background it. Host-specific addresses (`BCPC_SSH_HOST`) go in untracked
`~/.zshrc.private` because this repo is published. Both UIs need the forward up
first on BCLT.
