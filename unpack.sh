#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ln -s ${BASEDIR}/vim/vimrc ~/.vimrc
ln -s ${BASEDIR}/vim/vim ~/.vim
ln -s ${BASEDIR}/zsh/zshrc ~/.zshrc
