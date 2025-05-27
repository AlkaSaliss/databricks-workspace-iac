# live/dev/eu-west-1/databricks-workspace/terragrunt.hcl

include {
  path = find_in_parent_folders()
}

# Define a dependency on the backend module to ensure it's created first
dependency "backend" {
  config_path = "../backend"
  skip_outputs = true
}

inputs = {
  # These variables will be passed to your Terraform main.tf and variables.tf
  databricks_account_id = "YOUR_DATABRICKS_ACCOUNT_ID" # REPLACE with your Databricks Account ID
  databricks_pat        = "YOUR_DATABRICKS_PAT"        # REPLACE with your Databricks PAT
  workspace_name        = "my-tf-databricks-workspace" # Customize this name
}