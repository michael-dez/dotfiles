export PATH=$PATH:/usr/local/go/bin
export PATH="$HOME/.local/bin:$PATH"
# Install Ruby Gems to ~/gems
export GEM_HOME="$HOME/gems"

# Preferred editor for local and remote sessions
 if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
 else
   export EDITOR='nvim'
 fi
 # Kops
# Docker
export DOCKER_BUILDKIT=1
# kube
export KUBE_CONFIG_DEFAULT_LOCATION=~/.kube/config
export KUBECONFIG=~/.kube/config
# golang
export GOPATH="/home/mike/go"
export PATH="$PATH:/home/mike/go/bin"
# sops
# github
