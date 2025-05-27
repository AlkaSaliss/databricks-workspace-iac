# terragrunt.hcl

# Define common locals from the directory structure
locals {
  aws_account_id = split("/", get_terragrunt_dir())[length(split("/", get_terragrunt_dir())) - 2]
  aws_region     = split("/", get_terragrunt_dir())[length(split("/", get_terragrunt_dir())) - 1]
}

# Generate a versions.tf file in each module directory
# This ensures all modules use the same provider versions and a consistent backend config
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents = <<EOF
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.25"
    }
  }

  # Terragrunt will inject the backend configuration here
  # This block must be empty, or Terragrunt will error
  backend "s3" {}
}
EOF
}

# Define remote state configuration for all modules
remote_state {
  backend = "s3"
  config = {
    bucket         = "tf-state-${local.aws_account_id}-${local.aws_region}" # Bucket created by the 'backend' module
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "tf-lock-${local.aws_account_id}-${local.aws_region}" # Table created by the 'backend' module
    encrypt        = true
  }

  # This block is for when the backend *itself* is being created.
  # The 'backend' module will have its own terragrunt.hcl that overrides this to skip_init.
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt" # Allows terragrunt to generate this file
  }
}

# Define inputs to pass to all Terraform modules
inputs = {
  aws_region = local.aws_region
  prefix     = "dtb-${local.aws_account_id}-${local.aws_region}" # Dynamic prefix for resources
}

# Configure the AWS provider profile globally
terraform {
  extra_arguments "aws_profile" {
    commands = [
      "init",
      "plan",
      "apply",
      "destroy",
      "validate",
      "fmt"
    ]
    arguments = ["-var=aws_profile=${get_env("AWS_PROFILE", "default")}"]  
  }
}