terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.4" # Consistent with root versions.tf
    }
    # AWS provider might also be needed if any AWS resources/data sources were used directly in this module
    # For now, only adding databricks as it's the one causing the error.
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}