export ZSH="$HOME/.oh-my-zsh"
ssh-add -k "$HOME/.ssh/id_ed25519"
eval $(ssh-agent -s)

ZSH_THEME="agnoster"

plugins=(git)

source $ZSH/oh-my-zsh.sh
alias hbinds="cat ~/.config/hypr/hyprland.conf | grep \"bind = \""
alias n="nvim"
alias ll="ls -alh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
