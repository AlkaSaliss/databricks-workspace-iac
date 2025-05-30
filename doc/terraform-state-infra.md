# Terraform State Infrastructure Module

This Terraform module provisions the necessary AWS infrastructure for managing Terraform state. It creates an S3 bucket to store the state files and a DynamoDB table for state locking to prevent concurrent modifications.

## Purpose

- **S3 Bucket for State Storage**: Creates a secure S3 bucket to store Terraform state files (`terraform.tfstate`).
    - Configurable versioning to keep a history of state files.
    - Configurable server-side encryption (AES256) to protect state data at rest.
    - Public access block to ensure the bucket remains private.
    - Configurable lifecycle rules for managing object versions and incomplete multipart uploads.
- **DynamoDB Table for State Locking**: Creates a DynamoDB table to handle Terraform's state locking mechanism. This prevents multiple users or automation processes from running `terraform apply` simultaneously on the same state, which could lead to corruption or inconsistencies.

## Key Resources

- `aws_s3_bucket`: The S3 bucket for storing Terraform state files.
- `aws_s3_bucket_versioning`: Manages versioning for the S3 bucket.
- `aws_s3_bucket_server_side_encryption_configuration`: Configures server-side encryption for the S3 bucket.
- `aws_s3_bucket_public_access_block`: Enforces private access to the S3 bucket.
- `aws_s3_bucket_lifecycle_configuration`: Defines lifecycle rules for objects in the S3 bucket.
- `aws_dynamodb_table`: The DynamoDB table used for state locking.

## Variables

| Name                  | Description                                                                                                | Type                                                                                                                                    | Default | Required |
| --------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------- | -------- |
| `bucket_name`         | Name of the S3 bucket for Terraform state. Must be lowercase, alphanumeric, and can contain hyphens.       | `string`                                                                                                                                | -       | Yes      |
| `dynamodb_table_name` | Name of the DynamoDB table for Terraform state locking. Can contain letters, numbers, underscores, periods, and hyphens. | `string`                                                                                                                                | -       | Yes      |
| `enable_versioning`   | Enable versioning on the S3 bucket.                                                                        | `bool`                                                                                                                                  | `true`  | No       |
| `enable_encryption`   | Enable server-side encryption on the S3 bucket.                                                            | `bool`                                                                                                                                  | `true`  | No       |
| `lifecycle_rules`     | List of lifecycle rules for the S3 bucket. Each rule defines an ID, status, and optional configurations for noncurrent version expiration and aborting incomplete multipart uploads. | `list(object({ id = string, status = string, noncurrent_version_expiration = optional(object({ days = number })), abort_incomplete_multipart_upload = optional(object({ days_after_initiation = number })) }))` | `[]`    | No       |
| `common_tags`         | Common tags to apply to all resources.                                                                     | `map(string)`                                                                                                                           | `{}`    | No       |
| `additional_tags`     | Additional tags to apply to resources.                                                                     | `map(string)`                                                                                                                           | `{}`    | No       |