# Root root.hcl - Common configuration for all environments

locals {
  # Common tags to apply to all resources
  common_tags = {
    Project     = "databricks-workspace-iac"
    ManagedBy   = "terragrunt"
    Environment = "${path_relative_to_include()}"
  }

  # Parse environment from directory structure
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment      = local.environment_vars.locals.environment
  aws_region       = local.region_vars.locals.aws_region
  aws_profile_name = "default"
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "dbx-terraform-state-${local.environment}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "dbx-terraform-locks-${local.environment}"

    # Enable versioning and server-side encryption
    s3_bucket_tags = merge(local.common_tags, {
      Name = "dbx-terraform-state-${local.environment}-${local.aws_region}"
    })

    dynamodb_table_tags = merge(local.common_tags, {
      Name = "dbx-terraform-locks-${local.environment}"
    })
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "skip"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.4"
    }
  }
}

provider "aws" {
  region  = "${local.aws_region}"
  profile = "${local.aws_profile_name}"
  
  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}
EOF
}

# Configure retry and error handling
retry_max_attempts       = 3
retry_sleep_interval_sec = 5

# Terragrunt will copy the Terraform configurations specified by the source parameter
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    optional_var_files = [
      find_in_parent_folders("account.tfvars", "ignore"),
      find_in_parent_folders("region.tfvars", "ignore"),
      find_in_parent_folders("env.tfvars", "ignore")
    ]
  }

  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }

  extra_arguments "parallelism" {
    commands  = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=10"]
  }
}

# Input validation
inputs = {
  common_tags = local.common_tags
  environment = local.environment
  aws_region  = local.aws_region
}