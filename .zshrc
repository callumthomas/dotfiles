export ZSH="$HOME/.oh-my-zsh"

SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    echo "Initializing new SSH agent..."
    /usr/bin/ssh-agent > "${SSH_ENV}"
    chmod 600 "${SSH_ENV}"
    source "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add
}

# Source SSH settings, if applicable
if [ -f "${SSH_ENV}" ]; then
    source "${SSH_ENV}" > /dev/null
    # Check if the socket actually exists and is a socket
    if [ ! -S "$SSH_AUTH_SOCK" ]; then
        start_agent
    fi
    # Check if agent is still running
    ps -p ${SSH_AGENT_PID} > /dev/null 2>&1 || {
        start_agent
    }
else
    start_agent
fi

ZSH_THEME="agnoster"

plugins=(git)

source $ZSH/oh-my-zsh.sh
alias hbinds="cat ~/.config/hypr/hyprland.conf | grep \"bind = \""
alias n="nvim"
alias ll="ls -alh"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH=$HOME/.local/bin:$PATH

awslogin() {
    aws sso login --profile "$AWS_PROFILE"
}

if [[ -n "$TMUX" && -n "$(tmux display-message -p '#S' 2>/dev/null)" ]]; then
    SESSION_NAME=$(tmux display-message -p '#S')
    SESSION_CONFIG="$HOME/.config/sessions/${SESSION_NAME}.zsh"
    
    if [[ -f "$SESSION_CONFIG" ]]; then
        source "$SESSION_CONFIG"
    fi
fi
