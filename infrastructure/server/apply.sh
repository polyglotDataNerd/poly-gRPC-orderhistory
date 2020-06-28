#!/usr/bin/env bash
#sampe call
# source ~/sg-gRPC-orderhistory/infrastructure/environment/consumer_ecs_infra_apply.sh 'production'

AWS_ACCESS_KEY_ID=$(aws ssm get-parameters --names /s3/admin/AccessKey --query Parameters[0].Value --with-decryption --output text)
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameters --names /s3/admin/SecretKey --query Parameters[0].Value --with-decryption --output text)
CURRENTDATE="$(date +%Y)"
GitToken=$(aws ssm get-parameters --names /s3/admin/GitToken --query Parameters[0].Value --with-decryption --output text)
EpochTag="$(date +%s)"
GitHash=$(cd ~/sg-gRPC-orderhistory && (git rev-parse --verify HEAD))
#shell parameter for env.
environment=$1
image="447388672287.dkr.ecr.us-west-2.amazonaws.com/sg-orderhistory-$environment:$EpochTag"

# INFRASTRUCTURE
aws s3 cp s3://bigdata-utility/terraform/orderhistory/$environment/server/infra/$CURRENTDATE ~/sg-gRPC-orderhistory/infrastructure/server/infra --recursive --sse --quiet --include "*"
# infra variables
export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
export TF_VAR_image=$image

cd ~/sg-gRPC-orderhistory/infrastructure/server/infra
terraform init
terraform get
terraform validate -check-variables=false
terraform plan
terraform apply -auto-approve
terraform refresh

#copy tfstate files to s3
aws s3 cp ~/sg-gRPC-orderhistory/infrastructure/server/infra/ s3://bigdata-utility/terraform/orderhistory/$environment/server/infra/$CURRENTDATE/ --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"

# DOCKER BUILD
cd ~/sg-gRPC-orderhistory/infrastructure/server/build
docker build -f Dockerfile \
  -t orderhistory-$environment:$EpochTag -t sg-orderhistory-$environment:$EpochTag \
  --build-arg AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  --build-arg AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  --build-arg GitToken=$GitToken \
  --build-arg GitHash=$GitHash \
  --force-rm \
  --no-cache .
#tag docker $image
docker tag orderhistory-$environment:$EpochTag $image
eval "$(aws ecr get-login --region us-west-2 --no-include-email)"
docker push $image

# APPLICATION SERVICE
aws s3 cp s3://bigdata-utility/terraform/orderhistory/$environment/server/app/$CURRENTDATE ~/sg-gRPC-orderhistory/infrastructure/server/app --recursive --sse --quiet --include "*"

# app variables
export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
export TF_VAR_image=$image

cd ~/sg-gRPC-orderhistory/infrastructure/server/app
terraform init
terraform get
terraform validate -check-variables=false
terraform plan
terraform apply -auto-approve
terraform refresh

#copy tfstate files to s3
aws s3 cp ~/sg-gRPC-orderhistory/infrastructure/server/app/ s3://bigdata-utility/terraform/orderhistory/$environment/server/app/$CURRENTDATE/ --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"

cd ~/sg-gRPC-orderhistory/