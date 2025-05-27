# live/dev/eu-west-1/backend/terragrunt.hcl

include {
  path = find_in_parent_folders()
}

# This is the module that creates the S3 backend and DynamoDB table.
# Therefore, it cannot use the remote_state configuration defined in the parent
# terragrunt.hcl, as that backend doesn't exist yet.
# We set disable_init = true to prevent Terragrunt from trying to initialize the
# remote state for this specific module.
remote_state {
  disable_init = true
}

locals {
  aws_account_id = "dev"
  aws_region     = "eu-west-1"
}

inputs = {
  bucket_name = "tf-state-${local.aws_account_id}-${local.aws_region}"
  table_name  = "tf-lock-${local.aws_account_id}-${local.aws_region}"
}