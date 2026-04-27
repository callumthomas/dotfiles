function ddev
    set -l project
    set -l project_path

    if set -q argv[1]
        set project $argv[1]
        set project_path ~/dev/denv/services/$argv[1]
    else
        set project (basename (pwd))
        set project_path (pwd)
    end

    set project (string replace -a '.' '_' -- $project)
    set project (string replace -a ':' '_' -- $project)
    
    function ensure_window
        set -l session $argv[1]
        set -l window_name $argv[2]
        set -l path $argv[3]
        set -l command $argv[4]
        
        if not tmux list-windows -t =$session -F '#{window_name}' | grep -q "^$window_name\$"
            echo "no $window_name found for $session, creating"
            tmux new-window -t =$session -n $window_name -c $path
            if test -n "$command"
                tmux send-keys -t =$session:$window_name $command C-m
            end
        end
    end
    
    if not tmux has-session -t =$project 2>/dev/null
        tmux new-session -d -c $project_path -s $project
        tmux rename-window -t =$project:1 vim
        tmux send-keys -t =$project:vim 'vim .' C-m
		tmux new-window -t =$project -n claude -c $project_path
		tmux send-keys -t =$project:claude 'cc' C-m
        tmux new-window -t =$project -n shell -c $project_path
    else
        ensure_window $project vim $project_path 'vim .'
		ensure_window $project claude $project_path 'claude'
        ensure_window $project shell $project_path
    end

    tmux select-window -t =$project:vim
    tmux attach-session -t =$project
end
