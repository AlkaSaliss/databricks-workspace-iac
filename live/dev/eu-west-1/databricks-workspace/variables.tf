# live/dev/eu-west-1/databricks-workspace/variables.tf

variable "aws_region" {
  description = "AWS region where the Databricks workspace will be deployed."
  type        = string
}

variable "aws_profile" {
  description = "The AWS CLI profile to use."
  type        = string
}

variable "databricks_account_id" {
  description = "Your Databricks Account ID (from accounts.cloud.databricks.com)."
  type        = string
  sensitive   = true
}

variable "databricks_pat" {
  description = "Databricks Personal Access Token for the Account API."
  type        = string
  sensitive   = true
}

variable "workspace_name" {
  description = "A unique name for your Databricks workspace."
  type        = string
  default     = "my-tf-databricks-workspace"
}

variable "prefix" {
  description = "A short prefix for all AWS resources created."
  type        = string
}

# --- Networking Variables for VPC setup ---
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (e.g., for NAT Gateway)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (where Databricks compute will run)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}