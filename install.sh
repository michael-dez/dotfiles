#!/usr/bin/env bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#ln -fs ${BASEDIR}/vim/vimrc ~/.vimrc
#ln -fs ${BASEDIR}/nvim/ ~/.config/nvim
#ln -fs ${BASEDIR}/zsh/zshrc ~/.zshrc
#ln -fs ${BASEDIR}/zsh/p10k.zsh ~/.p10k.zsh
#ln -fs ${BASEDIR}/zsh/zshenv ~/.zshenv
#ln -fs ${BASEDIR}/zsh/oh-my-zsh ~/.oh-my-zsh
#ln -fs ${BASEDIR}/i3/ ~/.config/
#ln -fs ${BASEDIR}/xfce4/ ~/.config/
#ln -fs ${BASEDIR}/picom/picom.conf ~/.config/picom/picom.conf
#ln -fs ${BASEDIR}/tmux/tmux.conf ~/.tmux.conf
#ln -fst ${HOME}/.config/texinfo ${BASEDIR}/texinfo/infokey
_link_home_files()
{
    ln -fsT ${BASEDIR}/$1 ${HOME}/.$1
}

_link_xdg_files()
{
    local config_dir="${HOME}/.config/$1"
    [ ! -d "$config_dir" ] && mkdir -p $config_dir
    ln -fsT ${BASEDIR}/$1/$2 ${config_dir}/$2
}

# make fonts directory if does not exist and unzip fonts to that directory
_fonts()
{
    fonts="/home/$USER/.local/share/fonts"
    [ ! -d "$fonts" ] && mkdir $fonts
    unzip ${BASEDIR}/fonts/MesloLGS.zip -d $fonts
}

#_fonts
_link_home_files vimrc
_link_home_files tmux.conf
_link_home_files zshenv
_link_home_files zshrc
_link_home_files zshrc.pre-oh-my-zsh
_link_home_files p10k.zsh

_link_xdg_files nvim init.lua
_link_xdg_files picom picom.conf
_link_xdg_files texinfo infokey
_link_xdg_files xfce4 terminal/terminalrc
_link_xdg_files xfce4 terminal/accels.scm
_link_xdg_files xfce4 xfconf/xfce-perchannel-xml/xfce4-terminal.xml
# TODO: add option to restore from bak folder
