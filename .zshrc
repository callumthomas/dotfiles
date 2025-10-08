export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(git)

source $ZSH/oh-my-zsh.sh
alias hbinds="cat ~/.config/hypr/hyprland.conf | grep \"bind = \""
alias n="nvim"
alias ll="ls -alh"
