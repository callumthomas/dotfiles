kubectl config use prod
set -gx AWS_PROFILE delio-prod
echo "Prod access configured, use \"awslogin\" to initiate SSO"
