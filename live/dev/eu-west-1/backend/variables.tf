# live/dev/eu-west-1/backend/variables.tf

variable "bucket_name" {
  description = "The name for the S3 bucket to store Terraform state."
  type        = string
}

variable "table_name" {
  description = "The name for the DynamoDB table for Terraform state locking."
  type        = string
}

variable "aws_region" {
  description = "The AWS region."
  type        = string
}

variable "aws_profile" {
  description = "The AWS CLI profile to use."
  type        = string
}

variable "prefix" {
  description = "A prefix for resource names."
  type        = string
}