#            _____                    _____                    _____                    _____                    _____          
#           /\    \                  /\    \                  /\    \                  /\    \                  /\    \         
#          /::\    \                /::\    \                /::\____\                /::\    \                /::\    \        
#          \:::\    \              /::::\    \              /:::/    /               /::::\    \              /::::\    \       
#           \:::\    \            /::::::\    \            /:::/    /               /::::::\    \            /::::::\    \      
#            \:::\    \          /:::/\:::\    \          /:::/    /               /:::/\:::\    \          /:::/\:::\    \     
#             \:::\    \        /:::/__\:::\    \        /:::/____/               /:::/__\:::\    \        /:::/  \:::\    \    
#              \:::\    \       \:::\   \:::\    \      /::::\    \              /::::\   \:::\    \      /:::/    \:::\    \   
#               \:::\    \    ___\:::\   \:::\    \    /::::::\    \   _____    /::::::\   \:::\    \    /:::/    / \:::\    \  
#                \:::\    \  /\   \:::\   \:::\    \  /:::/\:::\    \ /\    \  /:::/\:::\   \:::\____\  /:::/    /   \:::\    \ 
#  _______________\:::\____\/::\   \:::\   \:::\____\/:::/  \:::\    /::\____\/:::/  \:::\   \:::|    |/:::/____/     \:::\____\
#  \::::::::::::::::::/    /\:::\   \:::\   \::/    /\::/    \:::\  /:::/    /\::/   |::::\  /:::|____|\:::\    \      \::/    /
#   \::::::::::::::::/____/  \:::\   \:::\   \/____/  \/____/ \:::\/:::/    /  \/____|:::::\/:::/    /  \:::\    \      \/____/ 
#    \:::\~~~~\~~~~~~         \:::\   \:::\    \               \::::::/    /         |:::::::::/    /    \:::\    \             
#     \:::\    \               \:::\   \:::\____\               \::::/    /          |::|\::::/    /      \:::\    \            
#      \:::\    \               \:::\  /:::/    /               /:::/    /           |::| \::/____/        \:::\    \           
#       \:::\    \               \:::\/:::/    /               /:::/    /            |::|  ~|               \:::\    \          
#        \:::\    \               \::::::/    /               /:::/    /             |::|   |                \:::\    \         
#         \:::\____\               \::::/    /               /:::/    /              \::|   |                 \:::\____\        
#          \::/    /                \::/    /                \::/    /                \:|   |                  \::/    /        
#           \/____/                  \/____/                  \/____/                  \|___|                   \/____/         
#                                                                                                                               
# Me: Mike Mendez
#
#
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Install oh-my-zsh if not already installed
if [ ! -d "/home/$USER/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh for user $USER..."
  /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

if [ ! -d "/home/$USER/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting for user $USER..."
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  echo "Installing powerlevel10k for user $USER..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Path to your oh-my-zsh installation.
export ZSH="/home/$USER/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git vi-mode fzf aws kubectl zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Set keymap for laptop on xorg if setxkbmap is available
command -v setxkbmap >/dev/null 2>&1 && \
setxkbmap -layout us  -option ctrl:nocaps

# Store distribution name as variable
if [ -f /etc/os-release ]; then
  . /etc/os-release
  export DISTRO=$NAME
else
  export DISTRO="unknown"
fi

# export Pacman package list if distro is EndeavourOS or Arch Linux
if [[ "$NAME" == "EndeavourOS Linux" || "$DISTRO" == "Arch Linux" ]]; then
  pkgs=/home/${USER}/repos/dotfiles/bak
  pacman -Qqe | grep -Fvx "$(pacman -Qqm)" > ${pkgs}/pacman-export.txt
  pacman -Qqm > ${pkgs}/aur-export.txt
  pip3 freeze > ${pkgs}/pip3-export.txt
fi

# if distribution is Ubuntu, set FZF_BASE
if [[ "$NAME" == "Ubuntu" ]]; then
  export FZF_BASE="/home/linuxbrew/.linuxbrew/bin/"
  eval $(/home/linux/.linuxbrew/bin/brew shellenv)
else
  export FZF_BASE="/usr/bin/fzf"
fi

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

#autoload -U edit-command-line (full screen comand edit on Esc-v)
zle -N edit-command-line
bindkey -M vicmd v edit-command-line
# aliases
alias p3="python3"
alias F="sudo !!"
alias vi="$EDITOR"
alias s3="aws s3"
#alias k="minikube kubectl --"
alias zshrc="$EDITOR ~/.zshrc"
alias zshenv="$EDITOR ~/.zshenv"
alias szshrc='. ~/.zshrc'
alias szshenv='. ~/.zshenv'
alias r="cd ~/repos"
alias n="cd ~/notes"
# git
alias gs="git status"
alias gc="git commit"
alias ga="git add"
alias ghm='cd $(git rev-parse --show-toplevel)'
# kube
alias ktx="kubectx"
alias kns="kubens"

# misc aliases
## record asciinema asciicast
alias arec="asciinema rec"
## convert asciicast to gif
alias a2gif='sudo docker run --rm -v "${PWD}":/data asciinema/asciicast2gif'
## run Microsoft Teams flatpak
alias teams='flatpak run com.microsoft.Teams'
## set brightness for Thinkpad t14 gen1 arg=0-1.0
alias light='xrandr --output eDP --brightness'
## search notes to edit
alias ze='zk edit -i'
alias zi='zk index'
alias cdz='cd ~/repos/slipbox'

# completion
## qmk completion if qmk_firmware repo exists
[ -d /home/mike/repos/qmk_firmware ] && \
source /home/mike/repos/qmk_firmware/util/qmk_tab_complete.sh
autoload -Uz bashcompinit && bashcompinit

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[ -d /usr/share/z ] && . /usr/share/z/z.sh
