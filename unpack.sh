#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -fs ${BASEDIR}/vim/vimrc ~/.vimrc
ln -fs ${BASEDIR}/vim/vim ~/.vim
ln -fs ${BASEDIR}/nvim/init.vim ~/.config/nvim/init.vim
ln -fs ${BASEDIR}/zsh/zshrc ~/.zshrc
ln -fs ${BASEDIR}/zsh/p10k.zsh ~/.p10k.zsh
ln -fs ${BASEDIR}/zsh/zshenv ~/.zshenv
ln -fs ${BASEDIR}/zsh/oh-my-zsh ~/.oh-my-zsh
ln -fs ${BASEDIR}/i3/config ~/.config/i3/config
ln -fs ${BASEDIR}/picom/picom.conf ~/.config/picom/picom.conf

# make fonts directory if does not exist and unzip fonts to that directory
fonts="/home/$USER/.local/share/fonts"
[ ! -d "$fonts" ] && mkdir $fonts
unzip ${BASEDIR}/fonts/MesloLGS.zip -d $fonts

# make i3 directory if does not exist and adds symlink to directory

