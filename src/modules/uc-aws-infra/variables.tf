# Variables for Unity Catalog AWS Infrastructure Module

variable "tags" {
  default     = {}
  type        = map(string)
  description = "(Optional) List of tags to be propagated across all assets in this module"
}

variable "prefix" {
  type        = string
  description = "(Required) Prefix to name the resources created by this module"
}

variable "region" {
  type        = string
  description = "(Required) AWS region where the assets will be deployed"
}

variable "cidr_block" {
  type        = string
  description = "(Required) CIDR block for the VPC that will be used to create the Databricks workspace"
}

variable "databricks_account_id" {
  type        = string
  description = "(Required) Databricks Account ID"
}

variable "workspace_name" {
  type        = string
  default     = ""
  description = "(Optional) Workspace Name for this module - if none are provided, the prefix will be used to name the workspace"
}

variable "unity_metastore_owner" {
  description = "(Required) Name of the principal that will be the owner of the Metastore"
  type        = string
}

variable "metastore_name" {
  description = "(Optional) Name of the metastore that will be created"
  type        = string
  default     = null
}

variable "databricks_client_id" {
  type        = string
  description = "(Required) Client ID to authenticate the Databricks provider at the account level"
  sensitive   = true
}

variable "databricks_client_secret" {
  type        = string
  description = "(Required) Client secret to authenticate the Databricks provider at the account level"
  sensitive   = true
}

variable "admin_group_id" {
  type        = string
  description = "(Required) The ID of the Databricks group to be granted admin permissions on the workspace."
}