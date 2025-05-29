# Version constraints for the entire project
# This file ensures consistent versions across all modules

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

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}