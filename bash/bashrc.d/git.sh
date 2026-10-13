# git aliases, same names as zshrc. Why: docs/bash.md#git
_have git || return 0

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gco='git checkout'
alias gl='git log --oneline --graph --decorate -20'
alias ghm='cd "$(git rev-parse --show-toplevel)"'
