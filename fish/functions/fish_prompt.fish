function fish_prompt
    set -l last_status $status
    
    # Your colors from Ghostty theme
    set -l color_host 0011ff       # blue
    set -l color_cwd 58d1eb        # cyan
    set -l color_git_clean 98e024  # green
    set -l color_git_dirty fd971f  # orange/yellow
    set -l color_git_branch 9d65ff # purple/blue
    
    # Username@hostname
    set_color $color_host
    echo -n $USER #@(prompt_hostname)

	set_color normal
	echo -n ':'
    
    # Current directory (abbreviated)
    set_color $color_cwd
    echo -n ' '(prompt_pwd --dir-length=1)
    
    # Git status
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l git_branch (git branch --show-current 2>/dev/null)
        
        if test -n "$git_branch"
            # Check if dirty
            if git diff-index --quiet HEAD -- 2>/dev/null
                set_color $color_git_clean
            else
                set_color $color_git_dirty
            end
            
            echo -n ' ('
            set_color $color_git_branch
            echo -n $git_branch
            
            if git diff-index --quiet HEAD -- 2>/dev/null
                set_color $color_git_clean
            else
                set_color $color_git_dirty
            end
            echo -n ')'
        end
    end
    
    # Prompt character
    set_color normal
    echo -n ' $: '
end
