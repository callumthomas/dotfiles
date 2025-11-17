if status is-interactive
end

# Source environment variables
if test -f ~/dev/dotfiles/.env
    for line in (cat ~/dev/dotfiles/.env | grep -v '^#' | grep -v '^$')
        set -gx (echo $line | cut -d= -f1) (echo $line | cut -d= -f2-)
    end
end

# SSH Agent Management
set -gx SSH_ENV "$HOME/.ssh/agent-environment"

function start_agent
    echo "Initializing new SSH agent..."
    /usr/bin/ssh-agent -c > $SSH_ENV
    chmod 600 $SSH_ENV
    source $SSH_ENV > /dev/null
    /usr/bin/ssh-add
end

# Source SSH settings, if applicable
if test -f $SSH_ENV
    source $SSH_ENV > /dev/null
    
    # Check if the socket actually exists and is a socket
    if not test -S "$SSH_AUTH_SOCK"
        start_agent
    else
        # Check if agent is still running
        ps -p $SSH_AGENT_PID > /dev/null 2>&1
        or start_agent
    end
else
    start_agent
end

# Aliases
alias hbinds="cat ~/.config/hypr/hyprland.conf | grep 'bind = '"
alias n="nvim"
alias ll="ls -alh"
alias febuild="tmux new -A -s fe-build"

# Add to PATH
fish_add_path $HOME/.local/bin

# NVM (Node Version Manager) for Fish
# Note: You'll need to install fisher and then: fisher install jorgebucaran/nvm.fish
# For now, here's a basic setup if you have nvm installed traditionally
set -gx NVM_DIR "$HOME/.nvm"

# AWS Login Function
function awslogin
    aws sso login --profile $AWS_PROFILE
end


# Tmux session-specific configuration
if set -q TMUX
    set SESSION_NAME (tmux display-message -p '#S' 2>/dev/null)
    
    if test -n "$SESSION_NAME"
        set SESSION_CONFIG "$HOME/.config/sessions/$SESSION_NAME.fish"
        
        if test -f "$SESSION_CONFIG"
            source $SESSION_CONFIG
        end
    end
end
