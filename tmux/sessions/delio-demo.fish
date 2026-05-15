kubectl config use demo
set -gx AWS_PROFILE delio-demo
if not aws sts get-caller-identity >/dev/null 2>&1
    aws sso login --profile $AWS_PROFILE
end
