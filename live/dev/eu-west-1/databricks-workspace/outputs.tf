# live/dev/eu-west-1/databricks-workspace/outputs.tf

output "workspace_url" {
  description = "The URL of the deployed Databricks workspace."
  value       = databricks_mws_workspace.this.workspace_url
}

output "workspace_id" {
  description = "The ID of the deployed Databricks workspace."
  value       = databricks_mws_workspace.this.workspace_id
}

output "vpc_id" {
  description = "The ID of the VPC created for the Databricks workspace."
  value       = aws_vpc.databricks_vpc.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs where Databricks compute runs."
  value       = aws_subnet.private_subnets[*].id
}