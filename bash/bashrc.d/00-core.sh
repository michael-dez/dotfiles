# Shared helpers and defaults. Why: docs/bash.md#core
_have() { command -v "$1" >/dev/null 2>&1; }

# Pick one line from stdin: fzf if present, else a numbered menu.
_pick() {
  local lines l
  mapfile -t lines
  (( ${#lines[@]} )) || return 1
  if (( ${#lines[@]} == 1 )); then
    printf '%s\n' "${lines[0]}"
  elif _have fzf; then
    printf '%s\n' "${lines[@]}" | fzf --height=40% --reverse
  else
    select l in "${lines[@]}"; do
      [[ -n $l ]] && { printf '%s\n' "$l"; return 0; }
    done </dev/tty
    return 1
  fi
}

HISTCONTROL=ignoreboth
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT='%F %T '
shopt -s histappend checkwinsize cmdhist globstar

: "${EDITOR:=vi}"
export EDITOR

alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias ..='cd ..'
alias grep='grep --color=auto'
