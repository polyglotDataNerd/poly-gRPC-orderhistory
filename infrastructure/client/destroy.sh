#!/usr/bin/env bash
#sampe call
# source ~/sg-gRPC-orderhistory/infrastructure/environment/consumer_ecs_infra_destroy.sh 'production'


AWS_ACCESS_KEY_ID=$(aws ssm get-parameters --names /s3/sweetgreen/admin/AccessKey --query Parameters[0].Value --with-decryption --output text)
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameters --names /s3/sweetgreen/admin/SecretKey --query Parameters[0].Value --with-decryption --output text)
CURRENTDATE="$(date  +%Y)"
#shell parameter for env.
environment=$1

# INFRASTRUCTURE
aws s3 cp s3://sweetgreen-bigdata-utility/terraform/orderhistory/$environment/client/infra/$CURRENTDATE ~/sg-gRPC-orderhistory/infrastructure/client/infra  --recursive --sse --quiet --include "*"

export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
export TF_VAR_image=$image
export TF_VAR_namespace=$ServiceNameSpace
cd ~/sg-gRPC-orderhistory/infrastructure/client/infra
terraform init
terraform destroy -auto-approve

#copy tfstate files to s3
aws s3 cp ~/sg-gRPC-orderhistory/infrastructure/client/infra/ s3://sweetgreen-bigdata-utility/terraform/orderhistory/$environment/client/infra/$CURRENTDATE/  --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"


# APPLICATION SERVICE
aws s3 cp s3://sweetgreen-bigdata-utility/terraform/orderhistory/$environment/client/app/$CURRENTDATE ~/sg-gRPC-orderhistory/infrastructure/client/app  --recursive --sse --quiet --include "*"

export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
export TF_VAR_image=$image
export TF_VAR_namespace=$ServiceNameSpace
cd ~/sg-gRPC-orderhistory/infrastructure/client/app
terraform init
terraform destroy -auto-approve

#copy tfstate files to s3
aws s3 cp ~/sg-gRPC-orderhistory/infrastructure/client/app/ s3://sweetgreen-bigdata-utility/terraform/orderhistory/$environment/client/app/$CURRENTDATE/  --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"

cd ~/sg-gRPC-orderhistory/
