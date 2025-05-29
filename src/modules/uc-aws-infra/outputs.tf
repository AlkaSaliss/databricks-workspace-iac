# Outputs for Unity Catalog AWS Infrastructure Module

# VPC Outputs
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "security_group_ids" {
  value       = [module.vpc.default_security_group_id]
  description = "Security group ID for DB Compliant VPC"
}

output "subnets" {
  value       = module.vpc.private_subnets
  description = "Private subnets for workspace creation"
}

output "vpc_main_route_table_id" {
  value       = module.vpc.vpc_main_route_table_id
  description = "ID for the main route table associated with this VPC"
}

output "private_route_table_ids" {
  value       = module.vpc.private_route_table_ids
  description = "IDs for the private route tables associated with this VPC"
}

# S3 Outputs
output "root_bucket" {
  value       = aws_s3_bucket.root_storage_bucket.bucket
  description = "Root storage bucket name"
}

output "metastore_bucket" {
  value       = aws_s3_bucket.metastore.bucket
  description = "Unity Catalog metastore bucket name"
}

# IAM Outputs
output "cross_account_role_arn" {
  value       = aws_iam_role.cross_account_role.arn
  description = "AWS Cross account role ARN"
  depends_on  = [aws_iam_role_policy.cross_account_policy]
}

output "unity_catalog_iam_role_arn" {
  value       = aws_iam_role.metastore_data_access.arn
  description = "Unity Catalog metastore data access IAM role ARN"
}

# Databricks Workspace Outputs
output "databricks_workspace_id" {
  value       = databricks_mws_workspaces.this.workspace_id
  description = "Databricks workspace ID"
}

output "databricks_workspace_url" {
  value       = databricks_mws_workspaces.this.workspace_url
  description = "Databricks workspace URL"
}

output "databricks_host" {
  value       = databricks_mws_workspaces.this.workspace_url
  description = "Databricks workspace host URL"
}

# Unity Catalog Outputs
output "unity_catalog_metastore_id" {
  description = "Unity Catalog Metastore ID"
  value       = databricks_metastore.this.id
}

output "unity_catalog_metastore_name" {
  description = "Unity Catalog Metastore Name"
  value       = databricks_metastore.this.name
}