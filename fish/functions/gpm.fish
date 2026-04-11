function gpm --description "Checkout main/master and pull"
    set -l branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if test -z "$branch"
        # Fallback: check which exists locally
        if git show-ref --verify --quiet refs/heads/main
            set branch main
        else if git show-ref --verify --quiet refs/heads/master
            set branch master
        else
            echo "Could not determine main branch"
            return 1
        end
    end
    git checkout $branch && git pull
end
