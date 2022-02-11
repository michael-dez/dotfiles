#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -s ${BASEDIR}/vim/vimrc ~/.vimrc
ln -s ${BASEDIR}/vim/vim ~/.vim
ln -s ${BASEDIR}/nvim/init.vim ~/.config/nvim/init.vim
ln -s ${BASEDIR}/zsh/zshrc ~/.zshrc
ln -s ${BASEDIR}/zsh/p10k.zsh ~/.p10k.zsh
ln -s ${BASEDIR}/zsh/zshenv ~/.zshenv
ln -s ${BASEDIR}/zsh/oh-my-zsh ~/.oh-my-zsh
