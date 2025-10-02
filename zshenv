export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/.local/bin:$PATH"
# Install Ruby Gems to ~/gems
export GEM_HOME="$HOME/gems"
# Docker
export DOCKER_BUILDKIT=1
# kube
export KUBE_CONFIG_DEFAULT_LOCATION=~/.kube/config
export KUBECONFIG=~/.kube/config
# golang
export GOPATH="/home/${USER}/go"
export PATH="${PATH}:/home/${USER}/go/bin"
# npm
export NPM_CONFIG_PREFIX="$HOME/.local"
# Preferred editor for local and remote sessions
 if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
 else
   export EDITOR='nvim'
 fi
# GPG
export GPG_TTY=$(tty)
