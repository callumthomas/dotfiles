tmux set-option status-style 'bg=#{?window_zoomed_flag,#af5fd7,magenta},fg=black'

kubectl config use prod
set -gx AWS_PROFILE delio-prod
if not aws sts get-caller-identity >/dev/null 2>&1
    aws sso login --profile $AWS_PROFILE
end
