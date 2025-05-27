# Databricks workspace deployment Guide using Terragrunt
This guide will walk you through the process of setting up a Databricks workspace using Terraform and Terragrunt.
---
**Introduction to Terraform and Terragrunt:**

Terragrunt helps you keep your Terraform configurations DRY (Don't Repeat Yourself) and manage dependencies between modules.

---

**Understanding the Terragrunt Structure:**

We'll use a standard Terragrunt "live" architecture:

```
.
├── terragrunt.hcl          # Global Terragrunt configuration (provider, remote_state defaults)
├── live/                   # Top-level directory for your "live" environments
│   └── aws-account-id/     # Placeholder for your AWS Account ID (or environment name)
│       └── us-east-1/      # Placeholder for your AWS region
│           ├── backend/    # Module to create S3 bucket and DynamoDB table
│           │   ├── main.tf
│           │   ├── variables.tf
│           │   ├── outputs.tf
│           │   └── terragrunt.hcl
│           └── databricks-workspace/ # Module to deploy Databricks workspace
│               ├── main.tf
│               ├── variables.tf
│               ├── outputs.tf
│               └── terragrunt.hcl
└── modules/                # Reusable Terraform modules (optional for this guide, but good practice)
    └── # (Your Databricks module could go here if it were reusable)
```

**Prerequisites:**

1.  **AWS Account:** With administrative access.
2.  **Databricks Account:** Existing account at `accounts.cloud.databricks.com`.
3.  **Terraform Installed:** (`terraform version`).
4.  **Terragrunt Installed:** (`terragrunt --version`). Install from [https://terragrunt.gruntwork.io/docs/getting-started/install/](https://terragrunt.gruntwork.io/docs/getting-started/install/).
5.  **AWS CLI Installed:** Configured with credentials that have sufficient permissions (`aws configure`).
6.  **`jq` installed:** (`sudo apt-get install jq` or `brew install jq`).

---

**Step 0: Initial AWS and Databricks Setup**

**0.1. Obtain Databricks Account ID and Generate a Personal Access Token (PAT)**

1.  **Log in to Databricks Account Console:** Go to `accounts.cloud.databricks.com` and log in.
2.  **Get Account ID:** Your Account ID is displayed on the homepage. **Note it down.**
3.  **Generate PAT:**
    *   Click on your user icon (top right) and select **User Settings**.
    *   Go to **Access tokens** tab.
    *   Click **Generate new token**.
    *   Give it a comment and lifetime.
    *   **CRITICAL:** Copy the generated token immediately. **You will not be able to see it again.** Store it securely.

**0.2. Configure AWS CLI Profile for Terraform/Terragrunt**

Use a dedicated IAM user for Terraform/Terragrunt with appropriate permissions (e.g., `AdministratorAccess` for this guide, then scope down).

```bash
aws configure --profile default
```
Enter your AWS Access Key ID, Secret Access Key, default region, and output format. This profile will be used by Terragrunt.

---

**Step 1: Set up Terragrunt Project Structure**

Create the directories:

```bash
mkdir -p live/your-aws-account-id/your-aws-region/backend
mkdir -p live/your-aws-account-id/your-aws-region/databricks-workspace
mkdir modules # (Optional, if you plan to extract reusable TF code)
cd terragrunt-databricks-workspace
```
**Important:** Replace `your-aws-account-id` and `your-aws-region` with your actual values. This structure allows you to manage multiple accounts/regions easily.

---

**Step 2: Define Global Terragrunt Configuration (`terragrunt.hcl`)**

Create `terragrunt.hcl` in the root of your project (`terragrunt-databricks-workspace/terragrunt.hcl`). This file sets up global variables and defines how Terragrunt generates `versions.tf` files for all modules.

```hcl
# terragrunt-databricks-workspace/terragrunt.hcl

# Define common locals from the directory structure
locals {
  aws_account_id = get_repo_root() |> path_relative_to_repo_root() |> basename |> url_decode # Assumes live/<aws-account-id>/...
  aws_region     = get_terragrunt_dir() |> path_relative_to_parent() |> basename # Assumes live/<aws-account-id>/<aws-region>/...
}

# Generate a versions.tf file in each module directory
# This ensures all modules use the same provider versions and a consistent backend config
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents = <<EOF
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.81"
    }
  }

  # Terragrunt will inject the backend configuration here
  # This block must be empty, or Terragrunt will error
  backend "s3" {}
}
EOF
}

# Define remote state configuration for all modules
remote_state {
  backend = "s3"
  config = {
    bucket         = "tf-state-${local.aws_account_id}-${local.aws_region}" # Bucket created by the 'backend' module
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "tf-lock-${local.aws_account_id}-${local.aws_region}" # Table created by the 'backend' module
    encrypt        = true
  }

  # This block is for when the backend *itself* is being created.
  # The 'backend' module will have its own terragrunt.hcl that overrides this to skip_init.
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt" # Allows terragrunt to generate this file
  }
}

# Define inputs to pass to all Terraform modules
inputs = {
  aws_region = local.aws_region
  prefix     = "dbx-${local.aws_account_id}-${local.aws_region}" # Dynamic prefix for resources
}

# Configure the AWS provider profile globally
terraform {
  extra_arguments "aws_profile" {
    commands = [
      "init",
      "plan",
      "apply",
      "destroy",
      "validate",
      "fmt"
    ]
    arguments = ["-var='aws_profile=${get_env("AWS_PROFILE", "default")}'"]
  }
}
```

**Explanation of `terragrunt.hcl`:**

*   **`locals`:** Extracts the AWS account ID and region from the directory path, making them reusable.
*   **`generate "versions"`:** This is crucial. It tells Terragrunt to create a `versions.tf` file in every module directory it runs, ensuring consistent provider versions and an empty `backend "s3"` block (Terragrunt fills this in).
*   **`remote_state`:** Defines the S3 backend and DynamoDB table for state locking. The bucket and table names are made dynamic based on the account ID and region.
*   **`inputs`:** Defines variables that will be passed automatically to all Terraform modules.
*   **`terraform.extra_arguments "aws_profile"`:** This injects the AWS CLI profile (`default`) as a Terraform variable to the `provider "aws"` block in `main.tf`.

---

**Step 3: Define Backend Terraform Module (`live/your-aws-account-id/your-aws-region/backend/`)**

This Terraform code will create the S3 bucket and DynamoDB table for state management.

**3.1. `live/your-aws-account-id/your-aws-region/backend/main.tf`**

```terraform
# live/your-aws-account-id/your-aws-region/backend/main.tf

provider "aws" {
  # Terragrunt will inject the region and profile
  # region = var.aws_region
  # profile = var.aws_profile
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = var.bucket_name
  acl    = "private" # Recommended to block public access

  versioning {
    enabled = true # Keep full history of your state files
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256" # Encrypt state at rest
      }
    }
  }

  tags = {
    Name        = "${var.prefix}-terraform-state"
    Environment = "Backend"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_block" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock_table" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST" # Cost-effective for low-usage locking
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.prefix}-terraform-lock"
    Environment = "Backend"
  }
}
```

**3.2. `live/your-aws-account-id/your-aws-region/backend/variables.tf`**

```terraform
# live/your-aws-account-id/your-aws-region/backend/variables.tf

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
```

**3.3. `live/your-aws-account-id/your-aws-region/backend/outputs.tf`**

```terraform
# live/your-aws-account-id/your-aws-region/backend/outputs.tf

output "s3_bucket_name" {
  description = "The name of the S3 bucket created for Terraform state."
  value       = aws_s3_bucket.terraform_state_bucket.bucket
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table created for Terraform state locking."
  value       = aws_dynamodb_table.terraform_lock_table.name
}
```

---

**Step 4: Define Backend Terragrunt Configuration (`live/your-aws-account-id/your-aws-region/backend/terragrunt.hcl`)**

```hcl
# live/your-aws-account-id/your-aws-region/backend/terragrunt.hcl

include {
  path = find_in_parent_folders()
}

# This is the module that creates the S3 backend and DynamoDB table.
# Therefore, it cannot use the remote_state configuration defined in the parent
# terragrunt.hcl, as that backend doesn't exist yet.
# We set skip_init = true to prevent Terragrunt from trying to initialize the
# remote state for this specific module.
remote_state {
  disable_init = true
  skip_init    = true # Deprecated, use disable_init
}

inputs = {
  bucket_name = "tf-state-${local.aws_account_id}-${local.aws_region}"
  table_name  = "tf-lock-${local.aws_account_id}-${local.aws_region}"
}
```

---

**Step 5: Define Databricks Workspace Terraform Module (`live/your-aws-account-id/your-aws-region/databricks-workspace/`)**

The Terraform files here are very similar to the previous guide, but they *do not* contain `terraform { backend "s3" }` blocks, as Terragrunt will inject that.

**5.1. `live/your-aws-account-id/your-aws-region/databricks-workspace/main.tf`**

```terraform
# live/your-aws-account-id/your-aws-region/databricks-workspace/main.tf

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
  profile = var.aws_profile # Injected via Terragrunt
}

# Configure the Databricks provider
provider "databricks" {
  host        = "https://accounts.cloud.databricks.com"
  account_id  = var.databricks_account_id
  token       = var.databricks_pat
}

# --- AWS Networking Setup ---

resource "aws_vpc" "databricks_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.prefix}-databricks-vpc"
    Environment = "Databricks"
  }
}

resource "aws_internet_gateway" "databricks_igw" {
  vpc_id = aws_vpc.databricks_vpc.id

  tags = {
    Name = "${var.prefix}-databricks-igw"
  }
}

resource "aws_eip" "databricks_nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.databricks_igw]

  tags = {
    Name = "${var.prefix}-databricks-nat-eip"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.databricks_vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = "${var.aws_region}${element(["a", "b"], count.index)}" # Adjust AZs based on region
  map_public_ip_on_launch = true # Public subnets need this for NAT GW

  tags = {
    Name = "${var.prefix}-public-subnet-${element(["a", "b"], count.index)}"
  }
}

resource "aws_nat_gateway" "databricks_nat_gateway" {
  allocation_id = aws_eip.databricks_nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id # Use the first public subnet for NAT Gateway

  tags = {
    Name = "${var.prefix}-databricks-nat-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.databricks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.databricks_igw.id
  }

  tags = {
    Name = "${var.prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.databricks_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = "${var.aws_region}${element(["a", "b"], count.index)}" # Adjust AZs based on region

  tags = {
    Name = "${var.prefix}-private-subnet-${element(["a", "b"], count.index)}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.databricks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.databricks_nat_gateway.id
  }

  tags = {
    Name = "${var.prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

# --- AWS IAM for Databricks Workspace ---

resource "aws_iam_role" "databricks_workspace_role" {
  name_prefix = "${var.prefix}-${var.workspace_name}-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Databricks AWS Account ID
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-databricks-workspace-role"
    Environment = "Databricks"
  }
}

resource "aws_iam_policy" "databricks_workspace_policy" {
  name_prefix = "${var.prefix}-${var.workspace_name}-policy-"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket", "s3:GetBucketLocation",
          "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration", "s3:DeleteLifecycleConfiguration", "s3:ListMultipartUploads",
          "s3:AbortMultipartUpload", "s3:ListAllMyBuckets", "s3:GetBucketTagging", "s3:PutBucketTagging",
          "s3:DeleteBucketTagging", "s3:GetBucketCORS", "s3:PutBucketCORS", "s3:DeleteBucketCORS",
          "s3:GetBucketVersioning", "s3:PutBucketVersioning", "s3:GetBucketLogging", "s3:PutBucketLogging",
          "s3:GetBucketWebsite", "s3:PutBucketWebsite", "s3:DeleteBucketWebsite", "s3:GetAccelerateConfiguration",
          "s3:PutAccelerateConfiguration"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict this to specific S3 buckets in production
      },
      {
        Action = [
          "ec2:AssociateDhcpOptions", "ec2:AssociateRouteTable", "ec2:AttachInternetGateway", "ec2:CreateDhcpOptions",
          "ec2:CreateInternetGateway", "ec2:CreateNatGateway", "ec2:CreateNetworkAcl", "ec2:CreateRoute",
          "ec2:CreateRouteTable", "ec2:CreateSecurityGroup", "ec2:CreateSubnet", "ec2:CreateTags",
          "ec2:CreateVolume", "ec2:CreateVpc", "ec2:DeleteDhcpOptions", "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway", "ec2:DeleteNetworkAcl", "ec2:DeleteRoute", "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup", "ec2:DeleteSubnet", "ec2:DeleteTags", "ec2:DeleteVolume",
          "ec2:DeleteVpc", "ec2:Describe*", "ec2:DetachInternetGateway", "ec2:DisassociateRouteTable",
          "ec2:ModifyVpcAttribute", "ec2:RevokeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress",
          "ec2:RunInstances", "ec2:StartInstances", "ec2:StopInstances", "ec2:TerminateInstances",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:AuthorizeSecurityGroupIngress", "ec2:AttachVolume",
          "ec2:DetachVolume", "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:AssociateAddress",
          "ec2:DisassociateAddress", "ec2:ModifyNetworkInterfaceAttribute", "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface", "ec2:AttachNetworkInterface", "ec2:DescribeNetworkInterfaces",
          "ec2:DescribePrefixLists", "ec2:DescribeVolumes", "ec2:DescribeSnapshots", "ec2:DescribeVpcs",
          "ec2:DescribeSubnets", "ec2:DescribeRouteTables", "ec2:DescribeSecurityGroups", "ec2:DescribePlacementGroups",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeRegions", "ec2:DescribeInstances", "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways", "ec2:DescribeVpcEndpoints", "ec2:ModifyVolume", "ec2:CreatePlacementGroup",
          "ec2:DeletePlacementGroup", "ec2:CreateDhcpOptions", "ec2:DeleteDhcpOptions", "ec2:AssociateDhcpOptions",
          "ec2:ReplaceDhcpOptions", "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions", "ec2:CreateFleet", "ec2:DeleteFleet", "ec2:DescribeFleets"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict this to specific resources in production
      },
      {
        Action = [
          "iam:CreateInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile", "iam:GetInstanceProfile", "iam:ListInstanceProfiles", "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict this to specific IAM resources in production
      },
      {
        Action = [
          "sts:AssumeRole"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict this to specific IAM roles in production
      },
      {
        Action = [
          "kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:CreateGrant",
          "kms:ListGrants", "kms:RevokeGrant", "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict this to specific KMS keys in production
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "databricks_workspace_policy_attachment" {
  role       = aws_iam_role.databricks_workspace_role.name
  policy_arn = aws_iam_policy.databricks_workspace_policy.arn
}

resource "aws_iam_instance_profile" "databricks_instance_profile" {
  name_prefix = "${var.prefix}-${var.workspace_name}-instance-profile-"
  role        = aws_iam_role.databricks_workspace_role.name
}

# --- Databricks Workspace Deployment ---

resource "databricks_mws_credentials" "this" {
  account_id   = var.databricks_account_id
  credentials_name = "${var.prefix}-${var.workspace_name}-credentials"
  role_arn     = aws_iam_role.databricks_workspace_role.arn
}

resource "databricks_mws_storage_configuration" "this" {
  account_id         = var.databricks_account_id
  storage_configuration_name = "${var.prefix}-${var.workspace_name}-storage"
  bucket_name        = "${var.prefix}-${var.workspace_name}-root-bucket-${data.aws_caller_identity.current.account_id}"
}

resource "databricks_mws_networks" "this" {
  account_id   = var.databricks_account_id
  network_name = "${var.prefix}-${var.workspace_name}-network"
  vpc_id       = aws_vpc.databricks_vpc.id
  subnet_ids   = aws_subnet.private_subnets[*].id
  security_group_ids = []
}

resource "databricks_mws_workspace" "this" {
  account_id                 = var.databricks_account_id
  aws_region                 = var.aws_region
  workspace_name             = var.workspace_name
  credentials_id             = databricks_mws_credentials.this.credentials_id
  storage_configuration_id   = databricks_mws_storage_configuration.this.storage_configuration_id
  network_id                 = databricks_mws_networks.this.network_id
}

# Data source to get current AWS account ID for unique S3 bucket name
data "aws_caller_identity" "current" {}
```

**5.2. `live/your-aws-account-id/your-aws-region/databricks-workspace/variables.tf`**

```terraform
# live/your-aws-account-id/your-aws-region/databricks-workspace/variables.tf

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
```

**5.3. `live/your-aws-account-id/your-aws-region/databricks-workspace/outputs.tf`**

```terraform
# live/your-aws-account-id/your-aws-region/databricks-workspace/outputs.tf

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
```

---

**Step 6: Define Databricks Workspace Terragrunt Configuration (`live/your-aws-account-id/your-aws-region/databricks-workspace/terragrunt.hcl`)**

```hcl
# live/your-aws-account-id/your-aws-region/databricks-workspace/terragrunt.hcl

include {
  path = find_in_parent_folders()
}

# Define a dependency on the backend module to ensure it's created first
dependency "backend" {
  # This path should point to the directory where the backend module is located
  config_path = "../backend"
  # Disable validation as this module doesn't use the outputs of the backend module
  # directly, but rather relies on the remote_state config in the parent terragrunt.hcl
  # to correctly find the backend that the 'backend' module created.
  # This is a subtle point: The 'dependency' block ensures the 'backend' module runs first.
  # The 'remote_state' block in the parent terragrunt.hcl is what tells *this* module
  # where its state should be stored (in the backend created by the 'backend' module).
  # We don't need to read outputs from 'backend' module, just ensure it completes.
  skip_outputs = true
}

inputs = {
  # These variables will be passed to your Terraform main.tf and variables.tf
  databricks_account_id = "YOUR_DATABRICKS_ACCOUNT_ID" # REPLACE with your Databricks Account ID
  databricks_pat        = "YOUR_DATABRICKS_PAT"        # REPLACE with your Databricks PAT
  workspace_name        = "my-tf-databricks-workspace" # Customize this name
}
```
**Important:** Replace `YOUR_DATABRICKS_ACCOUNT_ID` and `YOUR_DATABRICKS_PAT`.

---

**Step 7: Deploy with Terragrunt**

Now, navigate to the `live/your-aws-account-id/your-aws-region` directory (or its parent, if you want to apply all at once).

**7.1. Navigate to the base deployment directory:**

```bash
cd live/your-aws-account-id/your-aws-region
```

**7.2. Initialize, Plan, and Apply All Modules:**

Terragrunt's `run-all` command will automatically traverse the dependency graph (backend first, then workspace).

*   **Initialize:**
    ```bash
    terragrunt run-all init
    ```
    This will:
    1.  Run `backend` module: Terragrunt will skip `remote_state` init here and run `terraform init` to create `backend.tf` (empty), then run `terraform apply` to create the S3 bucket and DynamoDB table.
    2.  Run `databricks-workspace` module: Terragrunt will correctly initialize `remote_state` to use the newly created S3 backend, and then run `terraform init`.

*   **Plan:**
    ```bash
    terragrunt run-all plan
    ```
    This will show you the changes that will be applied for both the backend and the Databricks workspace. Review the plan carefully.

*   **Apply:**
    ```bash
    terragrunt run-all apply
    ```
    Type `yes` when prompted to confirm. This will deploy both the backend resources and the Databricks workspace.

    The deployment will proceed in order:
    1.  Backend S3 bucket and DynamoDB table will be created.
    2.  The Databricks workspace, VPC, IAM roles, etc., will be created. This step can take 10-20 minutes.

---

**Step 8: Verify the Deployment**

1.  **Check Terragrunt Output:** After `terragrunt run-all apply` completes, you'll see the outputs from the `databricks-workspace` module, including the `workspace_url`.
2.  **Databricks Account Console:** Log in to `accounts.cloud.databricks.com`. You should see your new workspace listed with a status of "Running".
3.  **AWS Console:**
    *   **S3:** Verify your state bucket (`tf-state-...`) and the Databricks root bucket (`dtb-...-root-bucket-...`) are created.
    *   **DynamoDB:** Verify your lock table (`tf-lock-...`) is created.
    *   **VPC:** Verify the VPC, subnets, IGW, NAT Gateway, and route tables have been created.
    *   **IAM:** Verify the IAM role and policy created for Databricks.
4.  **Log into Workspace:** Use the `workspace_url` to log in to your new Databricks workspace.

---

**Step 9: Clean Up (Optional but Recommended)**

When you no longer need the workspace and its infrastructure:

```bash
terragrunt run-all destroy
```
Type `yes` when prompted. This will remove all resources created by Terragrunt in the correct dependency order (Databricks workspace first, then backend resources).

---

**Important Considerations and Best Practices:**

*   **Sensitive Variables:** Always use Terragrunt's `inputs` in your `terragrunt.hcl` files for passing sensitive data like `databricks_pat` and `databricks_account_id`. **Never hardcode them directly into `main.tf` files or commit them to version control.** For even better security, use environment variables (e.g., `TF_VAR_databricks_pat` or AWS Secrets Manager with `data` sources).
*   **IAM Permissions:** The IAM policy provided is very broad. For production environments, strictly adhere to the principle of least privilege. Databricks provides a detailed list of required permissions in their documentation.
*   **Availability Zones:** The `element(["a", "b"], count.index)` for `availability_zone` assumes your region has at least 'a' and 'b' AZs. Some regions might have more or different suffixes. Adjust as needed.
*   **`local.aws_account_id` and `local.aws_region` extraction:** The `get_repo_root()` and `path_relative_to_repo_root()` functions work well with the recommended `live/account-id/region/` structure. Ensure your directory names match.
*   **Cost:** Databricks workspaces and the underlying AWS resources incur costs. Remember to destroy resources when no longer needed.
*   **Error Handling:** If an error occurs, Terragrunt will usually pinpoint which module failed. Navigate to that module's directory (`live/.../module_name`) and run `terragrunt plan` or `terragrunt apply` directly to debug.

This detailed guide now includes the benefits of Terragrunt for managing your Databricks workspace deployment, including the creation of the remote state backend!