#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -s ${BASEDIR}/vim/vimrc ~/.vimrc
ln -s ${BASEDIR}/vim/vim ~/.vim
ln -s ${BASEDIR}/nvim/init.vim ~/.config/nvim/init.vim
ln -s ${BASEDIR}/zsh/zshrc ~/.zshrc
ln -s ${BASEDIR}/zsh/p10k.zsh ~/.p10k.zsh
ln -s ${BASEDIR}/zsh/zshenv ~/.zshenv
ln -s ${BASEDIR}/zsh/oh-my-zsh ~/.oh-my-zsh

# make fonts directory if does not exist and unzip fonts to that directory
fonts="/home/$USER/.local/share/fonts"
[ ! -d "$fonts" ] && mkdir $fonts
unzip ${BASEDIR}/fonts/MesloLGS.zip -d $fonts
