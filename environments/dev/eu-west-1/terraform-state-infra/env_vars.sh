#!/bin/bash

# Please replace 'your-s3-bucket-name-dev' with your actual S3 bucket name for the dev environment.
export TF_STATE_BUCKET="dbx-terraform-state-dev-eu-west-1"
export TF_STATE_DYNAMODB_TABLE="dbx-terraform-locks-dev"

echo "Terraform backend environment variables set. Source this file before running Terragrunt commands: source env_vars.sh"