# Unity Catalog AWS Infrastructure Module

This Terraform module provisions the complete AWS infrastructure required to set up a Databricks workspace with Unity Catalog enabled. It handles networking, storage, IAM roles, and the Databricks workspace and metastore configurations.

## Purpose

- **VPC Setup**: Creates a Virtual Private Cloud (VPC) with public and private subnets, NAT Gateway, and an Internet Gateway. It also configures VPC endpoints for S3, STS, and Kinesis Streams to ensure private connectivity for Databricks services.
- **S3 Buckets**:
    - **Root Storage Bucket**: An S3 bucket for the Databricks workspace's root storage (DBFS).
    - **Metastore Bucket**: An S3 bucket to store Unity Catalog metastore data.
    Both buckets are configured with versioning disabled (can be enabled), server-side encryption (AES256), and public access blocks.
- **IAM Roles and Policies**:
    - **Cross-Account Role**: An IAM role that Databricks assumes to manage resources in your AWS account for the workspace.
    - **Unity Catalog Metastore Access Role**: An IAM role (`<prefix>-unity-catalog-metastore-access`) that Unity Catalog uses to access the metastore S3 bucket and sample data. It includes policies for S3 access and `sts:AssumeRole`.
- **Databricks Workspace Configuration (MWS)**:
    - `databricks_mws_credentials`: Configures credentials for Databricks to access your AWS account using the cross-account role.
    - `databricks_mws_networks`: Defines the network configuration for the workspace, linking it to the created VPC and subnets.
    - `databricks_mws_storage_configurations`: Sets up the root S3 bucket for the workspace.
    - `databricks_mws_workspaces`: Provisions the Databricks workspace itself in the specified AWS region.
- **Unity Catalog Metastore**:
    - `databricks_metastore`: Creates the Unity Catalog metastore, linking it to the metastore S3 bucket and specifying an owner.
    - `databricks_metastore_assignment`: Assigns the created metastore to the provisioned workspace.
- **Workspace Permissions**:
    - `databricks_mws_permission_assignment`: Grants ADMIN permissions on the newly created workspace to a specified Databricks group (via `admin_group_id` variable).

## Key Resources

- `terraform-aws-modules/vpc/aws`: Module to create the VPC and related networking resources.
- `aws_s3_bucket`: For root storage and metastore data.
- `aws_iam_role` & `aws_iam_policy`: For cross-account access and Unity Catalog data access.
- `databricks_mws_credentials`, `databricks_mws_networks`, `databricks_mws_storage_configurations`, `databricks_mws_workspaces`: Databricks provider resources for setting up the workspace via the MWS APIs.
- `databricks_metastore`, `databricks_metastore_assignment`: Databricks provider resources for creating and assigning the Unity Catalog metastore.
- `databricks_mws_permission_assignment`: For granting workspace admin rights.
- `time_sleep`: Used to introduce a delay for IAM propagation before creating dependent Databricks resources.

## Variables

| Name                        | Description                                                                                                | Type          | Default | Required |
| --------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------- | ------- | -------- |
| `tags`                      | (Optional) List of tags to be propagated across all assets in this module.                               | `map(string)` | `{}`    | No       |
| `prefix`                    | (Required) Prefix to name the resources created by this module.                                            | `string`      | -       | Yes      |
| `region`                    | (Required) AWS region where the assets will be deployed.                                                   | `string`      | -       | Yes      |
| `cidr_block`                | (Required) CIDR block for the VPC that will be used to create the Databricks workspace.                    | `string`      | -       | Yes      |
| `databricks_account_id`     | (Required) Databricks Account ID.                                                                          | `string`      | -       | Yes      |
| `workspace_name`            | (Optional) Workspace Name for this module - if none are provided, the prefix will be used.                 | `string`      | `""`    | No       |
| `unity_metastore_owner`     | (Required) Name of the principal (group) that will be the owner of the Metastore.                          | `string`      | -       | Yes      |
| `metastore_name`            | (Optional) Name of the metastore that will be created. If null, defaults to `"<prefix>-metastore"`.        | `string`      | `null`  | No       |
| `databricks_client_id`      | (Required) Client ID to authenticate the Databricks provider at the account level.                         | `string`      | -       | Yes      |
| `databricks_client_secret`  | (Required) Client secret to authenticate the Databricks provider at the account level.                     | `string`      | -       | Yes      |
| `admin_group_id`            | (Required) The ID of the Databricks group to be granted admin permissions on the workspace.                | `string`      | -       | Yes      |