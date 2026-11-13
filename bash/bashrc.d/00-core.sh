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

# History kept for turning into scripts: deduped, timestamped, written every prompt. Why: docs/bash.md#history
HISTCONTROL=ignoreboth
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT='%FT%TZ '
shopt -s histappend checkwinsize cmdhist lithist globstar
case $(declare -p PROMPT_COMMAND 2>/dev/null) in
  *'history -a'*) ;;
  'declare -a'*) PROMPT_COMMAND+=('history -a') ;;
  *) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a" ;;
esac
history() { TZ=UTC builtin history "$@"; }
set -o vi

# Prompt: last 3 dirs of pwd, git branch. Why: docs/bash.md#prompt
PROMPT_DIRTRIM=3
_ps1_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return 0
  printf ' (%s)' "$b"
}
PS1='\[\e[36m\]\w\[\e[35m\]$(_ps1_branch)\[\e[0m\]\$ '

: "${EDITOR:=vi}"
export EDITOR

alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lah'
alias ..='cd ..'
alias grep='grep --color=auto'
alias sbashrc='. ~/.bashrc'
