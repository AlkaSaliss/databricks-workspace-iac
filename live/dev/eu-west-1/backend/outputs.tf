# live/dev/eu-west-1/backend/outputs.tf

output "s3_bucket_name" {
  description = "The name of the S3 bucket created for Terraform state."
  value       = aws_s3_bucket.terraform_state_bucket.bucket
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table created for Terraform state locking."
  value       = aws_dynamodb_table.terraform_lock_table.name
}