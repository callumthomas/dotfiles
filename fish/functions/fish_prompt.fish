function fish_prompt
    set -l last_status $status
    
    # Your colors from Ghostty theme
    set -l color_host 0011ff       # blue
    set -l color_cwd 58d1eb        # cyan
    set -l color_git_clean 98e024  # green
    set -l color_git_dirty fd971f  # orange/yellow
    set -l color_git_branch 9d65ff # purple/blue
    
    # Username@hostname with gradient
    set -l userhost $USER@(prompt_hostname)
    set -l text_len (string length $userhost)
    set -l r_start 0x00; set -l g_start 0x11; set -l b_start 0xff
    set -l r_end 0xff; set -l g_end 0x00; set -l b_end 0xff
    for i in (seq 1 $text_len)
        set -l char (string sub -s $i -l 1 $userhost)
        set -l t (math "($i - 1) / ($text_len - 1)" 2>/dev/null; or echo 0)
        set -l r (math -s0 "$r_start + ($r_end - $r_start) * $t")
        set -l g (math -s0 "$g_start + ($g_end - $g_start) * $t")
        set -l b (math -s0 "$b_start + ($b_end - $b_start) * $t")
        set_color --bold (printf '%02x%02x%02x' $r $g $b)
        echo -n $char
    end
    set_color normal

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
