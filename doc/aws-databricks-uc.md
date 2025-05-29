Directory structure:
└── aws-databricks-uc/
    ├── README.md
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── terraform.tfvars
    ├── unity_catalog_infra.tf
    ├── variables.tf
    ├── workspace_metastore.tf
    ├── .terraform.lock.hcl
    └── images/

================================================
File: README.md
================================================
AWS Databricks Unity Catalog - Stage 2
=========================

In this template, we show how to dpeloy Unity Catalog related resources such as unity metastores, account level users and groups.

This is stage 2 of UC deployment, you can also run this stage 2 template directly without stage 1 (which helps you create `account admin` identity), but you need to make sure using account admin identity to authenticate the `databricks mws` provider, instead of using `account owner`. One major reason of not using `account owner` in terraform is you cannot destroy yourself from admin list.

If you don't have an `account admin` identity, you can refer to stage 1: 
[aws_databricks_unity_catalog_bootstrap](https://github.com/hwang-db/tf_aws_deployment/tree/main/aws_databricks_unity_catalog_bootstrap)

![alt text](https://raw.githubusercontent.com/databricks/terraform-databricks-examples/main/examples/aws-databricks-uc/images/uc-tf-onboarding.png?raw=true)

When running tf configs for UC resources, due to sometimes requires a few minutes to be ready and you may encounter errors along the way, so you can either wait for the UI to be updated before you apply and patch the next changes; or specifically add depends_on to accoune level resources

## Get Started

> Step 1: Fill in values in `terraform.tfvars`; also configure env necessary variables for AWS and Databricks provider authentication. Such as:


```bash
export TF_VAR_databricks_account_client_id=your_account_level_spn_application_id
export TF_VAR_databricks_account_client_secret=your_account_level_spn_secret
export TF_VAR_databricks_account_id=your_databricks_account_id

export AWS_ACCESS_KEY_ID=your_aws_role_access_key_id
export AWS_SECRET_ACCESS_KEY=your_aws_role_secret_access_key
``` 

> Step 2: Run `terraform init` and `terraform apply` to deploy the resources. This will deploy both AWS resources that Unity Catalog requires and Databricks Account Level resources.



================================================
File: main.tf
================================================
locals {
  prefix = "uc-test"
}

// create users and groups at account level (not workspace user/group)
resource "databricks_user" "unity_users" {
  provider  = databricks.mws
  for_each  = toset(concat(var.databricks_users, var.databricks_account_admins))
  user_name = each.key
  force     = true
}

resource "databricks_group" "admin_group" {
  provider     = databricks.mws
  display_name = var.unity_admin_group
}

resource "databricks_group_member" "admin_group_member" {
  provider  = databricks.mws
  for_each  = toset(var.databricks_account_admins)
  group_id  = databricks_group.admin_group.id
  member_id = databricks_user.unity_users[each.value].id
}


resource "databricks_user_role" "metastore_admin" { // this group is admin for metastore, also pre-requisite for creating metastore
  provider = databricks.mws
  for_each = toset(var.databricks_account_admins)
  user_id  = databricks_user.unity_users[each.value].id
  role     = "account_admin"
}

/*
resource "aws_s3_bucket" "external" {
  bucket = "${local.prefix}-external"
  acl    = "private"
  versioning {
    enabled = false
  }
  // destroy all objects with bucket destroy
  force_destroy = true
  tags = merge(local.tags, {
    Name = "${local.prefix}-external"
  })
}

resource "aws_s3_bucket_public_access_block" "external" {
  bucket             = aws_s3_bucket.external.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.external]
}

resource "aws_iam_policy" "external_data_access" {
  // Terraform's "jsonencode" function converts a
  // Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${aws_s3_bucket.external.id}-access"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.external.arn,
          "${aws_s3_bucket.external.arn}/*"
        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(local.tags, {
    Name = "${local.prefix}-unity-catalog external access IAM policy"
  })
}

resource "aws_iam_role" "external_data_access" {
  name                = "${local.prefix}-external-access"
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_uc.json
  managed_policy_arns = [aws_iam_policy.external_data_access.arn]
  tags = merge(local.tags, {
    Name = "${local.prefix}-unity-catalog external access IAM role"
  })
}


resource "databricks_storage_credential" "external" {
  provider = databricks.workspace
  name     = aws_iam_role.external_data_access.name
  aws_iam_role {
    role_arn = aws_iam_role.external_data_access.arn
  }
  comment = "Managed by TF"
}

resource "databricks_grants" "external_creds" {
  provider           = databricks.workspace
  storage_credential = databricks_storage_credential.external.id
  grant {
    principal  = "Data Engineers"
    privileges = ["CREATE_TABLE"]
  }
}

resource "databricks_external_location" "some" {
  provider        = databricks.workspace
  name            = "external"
  url             = "s3://${aws_s3_bucket.external.id}/some"
  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
}

resource "databricks_grants" "some" {
  provider          = databricks.workspace
  external_location = databricks_external_location.some.id
  grant {
    principal  = "Data Engineers"
    privileges = ["CREATE_TABLE", "READ_FILES"]
  }
}
*/



================================================
File: outputs.tf
================================================



================================================
File: providers.tf
================================================
terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

// initialize provider in "MWS" mode to provision new workspace
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id // like a shared account? HA from multiple email accounts
  client_id     = var.databricks_account_client_id
  client_secret = var.databricks_account_client_secret
  auth_type     = "oauth-m2m"
}

provider "databricks" {
  alias = "ws1"
  host  = "https://dbc-167215e3-dd0f.cloud.databricks.com"
  token = var.pat_ws_1
}

provider "databricks" {
  alias = "ws2"
  host  = "https://dbc-dc6a79a6-893f.cloud.databricks.com"
  token = var.pat_ws_2
}



================================================
File: terraform.tfvars
================================================
databricks_workspace_ids  = ["2424101092929547"]
databricks_users          = ["prashant.singh@databricks.com"]
databricks_account_admins = ["goinfrerie@gmail.com", "dominic.teo@databricks.com"] // do not fill in account owner; you can use UI to remove yourself from admin group, or by switching provider to another account admin
unity_admin_group         = "admin group A"



================================================
File: unity_catalog_infra.tf
================================================
// aws resources for UC
resource "aws_s3_bucket" "metastore" {
  bucket = "${local.prefix}-metastore-jlaw"
  acl    = "private"
  versioning {
    enabled = false
  }
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${local.prefix}-uc-metastore"
  })
}

resource "aws_s3_bucket_public_access_block" "metastore" {
  bucket                  = aws_s3_bucket.metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.metastore]
}

data "aws_iam_policy_document" "passrole_for_uc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
  statement {
    sid     = "ExplicitSelfRoleAssumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
      type        = "AWS"
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${var.aws_account_id}:role/${local.prefix}-uc-access"]
    }
  }
}

resource "aws_iam_policy" "unity_metastore" {
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.prefix}-databricks-unity-metastore"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.metastore.arn,
          "${aws_s3_bucket.metastore.arn}/*"
        ],
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "sts:AssumeRole"
        ],
        "Resource" : [
          "arn:aws:iam::${var.aws_account_id}:role/${local.prefix}-uc-access"
        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(var.tags, {
    Name = "${local.prefix}-unity-catalog IAM policy"
  })
}

// Required, in case https://docs.databricks.com/data/databricks-datasets.html are needed
resource "aws_iam_policy" "sample_data" {
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${local.prefix}-databricks-sample-data"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          "arn:aws:s3:::databricks-datasets-oregon/*",
          "arn:aws:s3:::databricks-datasets-oregon"
        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(var.tags, {
    Name = "${local.prefix}-unity-catalog IAM policy"
  })
}

resource "aws_iam_role" "metastore_data_access" {
  name                = "${local.prefix}-uc-access"
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_uc.json
  managed_policy_arns = [aws_iam_policy.unity_metastore.arn, aws_iam_policy.sample_data.arn]
  tags = merge(var.tags, {
    Name = "${local.prefix}-unity-catalog IAM role"
  })
}


resource "aws_s3_bucket" "external" {
  bucket = "${local.prefix}-external"
  acl    = "private"
  versioning {
    enabled = false
  }
  // destroy all objects with bucket destroy
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${local.prefix}-external"
  })
}

resource "aws_s3_bucket_public_access_block" "external" {
  bucket             = aws_s3_bucket.external.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.external]
}

resource "aws_iam_policy" "external_data_access" {
  // Terraform's "jsonencode" function converts a
  // Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${aws_s3_bucket.external.id}-access"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.external.arn,
          "${aws_s3_bucket.external.arn}/*"
        ],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(var.tags, {
    Name = "${local.prefix}-unity-catalog external access IAM policy"
  })
}



================================================
File: variables.tf
================================================
variable "databricks_account_client_id" {
  type        = string
  description = "Application ID of account-level service principal"
}

variable "databricks_account_client_secret" {
  type        = string
  description = "Client secret of account-level service principal"
}

variable "databricks_account_id" {
  type        = string
  description = "Databricks Account ID"
}

variable "aws_account_id" {
  type        = string
  description = "(Required) AWS account ID where the cross-account role for Unity Catalog will be created"
}

variable "region" {
  type        = string
  description = "AWS region to deploy to"
  default     = "ap-southeast-1"
}

variable "tags" {
  default     = {}
  type        = map(string)
  description = "Optional tags to add to created resources"
}

variable "databricks_workspace_ids" {
  description = <<EOT
  List of Databricks workspace IDs to be enabled with Unity Catalog.
  Enter with square brackets and double quotes
  e.g. ["111111111", "222222222"]
  EOT
  type        = list(string)
  default     = ["2424101092929547"]
}

variable "databricks_users" {
  description = <<EOT
  List of Databricks users to be added at account-level for Unity Catalog. should we put the account owner email here? maybe not since it's always there and we dont want tf to destroy
  Enter with square brackets and double quotes
  e.g ["first.last@domain.com", "second.last@domain.com"]
  EOT
  type        = list(string)
}


variable "databricks_account_admins" {
  description = <<EOT
  List of Admins to be added at account-level for Unity Catalog.
  Enter with square brackets and double quotes
  e.g ["first.admin@domain.com", "second.admin@domain.com"]
  EOT
  type        = list(string)
}

variable "unity_admin_group" {
  description = "Name of the admin group. This group will be set as the owner of the Unity Catalog metastore"
  type        = string
}

variable "pat_ws_1" {
  type      = string
  sensitive = true
}

variable "pat_ws_2" {
  type      = string
  sensitive = true
}



================================================
File: workspace_metastore.tf
================================================
// Create UC metastore
resource "databricks_metastore" "this" {
  provider      = databricks.ws1
  name          = "primary"
  storage_root  = "s3://${aws_s3_bucket.metastore.id}/metastore"
  owner         = var.unity_admin_group
  force_destroy = true
  depends_on = [
    databricks_group.admin_group,
    databricks_group_member.admin_group_member,
    databricks_user_role.metastore_admin,
  ]
}

resource "databricks_metastore_data_access" "this" {
  provider     = databricks.ws1
  metastore_id = databricks_metastore.this.id
  name         = aws_iam_role.metastore_data_access.name
  aws_iam_role {
    role_arn = aws_iam_role.metastore_data_access.arn
  }
  is_default = true
}

resource "databricks_metastore_assignment" "default_metastore" {
  provider             = databricks.ws1
  for_each             = toset(var.databricks_workspace_ids)
  workspace_id         = each.key
  metastore_id         = databricks_metastore.this.id
  default_catalog_name = "hive_metastore"
}

// metastore - catalog - schema - table
resource "databricks_catalog" "sandbox" {
  provider     = databricks.ws1
  metastore_id = databricks_metastore.this.id
  name         = "sandbox_catalog"
  comment      = "this catalog is managed by terraform"
  properties = {
    purpose = "testing"
  }
  depends_on = [databricks_metastore_assignment.default_metastore]
}

resource "databricks_grants" "sandbox" {
  provider = databricks.ws1
  catalog  = databricks_catalog.sandbox.name
  grant {
    principal  = "account users" // account users
    privileges = ["USAGE", "CREATE"]
  }
}

resource "databricks_schema" "things" {
  provider     = databricks.ws1
  catalog_name = databricks_catalog.sandbox.id
  name         = "schema_sample"
  comment      = "this database is managed by terraform"
  properties = {
    kind = "various"
  }
}

resource "databricks_grants" "things" {
  provider = databricks.ws1
  schema   = databricks_schema.things.id
  grant {
    principal  = "account users"
    privileges = ["USAGE", "CREATE"]
  }
}

resource "aws_iam_role" "external_data_access" {
  name                = "${local.prefix}-external-access"
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_uc.json
  managed_policy_arns = [aws_iam_policy.external_data_access.arn]
  tags = merge(var.tags, {
    Name = "${local.prefix}-unity-catalog external access IAM role"
  })
}

resource "databricks_storage_credential" "external" {
  provider = databricks.ws1
  name     = aws_iam_role.external_data_access.name
  aws_iam_role {
    role_arn = aws_iam_role.external_data_access.arn
  }
  comment = "Managed by TF"
}

resource "databricks_external_location" "some" {
  provider        = databricks.ws1
  name            = "external"
  url             = "s3://${aws_s3_bucket.external.id}/some"
  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
}

resource "databricks_grants" "some" {
  provider          = databricks.ws1
  external_location = databricks_external_location.some.id
  grant {
    principal  = "admin group A"
    privileges = ["CREATE_TABLE", "READ_FILES"]
  }
}



================================================
File: .terraform.lock.hcl
================================================
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/databricks/databricks" {
  version = "1.3.1"
  hashes = [
    "h1:ftL4JdcmEuwiB8W2Rs6Et+M0eanEa8KwW0rvlLEeyAQ=",
    "zh:0f549815379dfdcb2bd6e27959f49f8e5badbf192a83f633988f792605f0053d",
    "zh:0f579435dc1607776f11095652c23ff17ec1ccf3e72dec038d06b7b6b7850221",
    "zh:29a22ee31f9b68bd786993e5753f103cc861084f184d8503943aed050ddfad49",
    "zh:2a6e0730a49a1ccc4cd4f96ea96113da0d25e30cfde632ac5d3246cfa0277016",
    "zh:3b8fe58a743830ae59d0e12c30b3bb36afa4b974d7d2bc6a8b96d16436a2b838",
    "zh:409e29eb10658b7c7dd0f8e851154e6bda1a940a3db13b14c4e8a4a69b591986",
    "zh:87d4f641ae9a52ec340fbf3a3918c4a5a9f61b8ae36cea098db77812581c3da0",
    "zh:b846c39ca0b4fd774ea5186693aaa8f94bc82034c51be07e10766e74986ea130",
    "zh:bab7a9a42308f09ccf9a76248cc0c634ff4d2128a8fc3c622fd4e5d856aa3dce",
    "zh:bc488d5ee46efd4c9e6149759133061cd995540835c3fe7a64af97d7ad5ae19c",
  ]
}

provider "registry.terraform.io/hashicorp/aws" {
  version = "4.32.0"
  hashes = [
    "h1:d4aUL6/J+BFhh1/Nh2rgctt+dqf07H9PipRn297hIIo=",
    "zh:062c30cd8bcf29f8ee34c2b2509e4e8695c2bcac8b7a8145e1c72e83d4e68b13",
    "zh:1503fabaace96a7eea4d73ced36a02a75ec587760850e58162e7eff419dcbb31",
    "zh:39a1fa36f8cb999f048bf0000d9dab40b8b0c77df35584fb08aa8bd6c5052dee",
    "zh:471a755d43b51cd7be3e386cebc151ad8d548c5dea798343620476887e721882",
    "zh:61ed56fab811e62b8286e606d003f7eeb7e940ef99bb49c1d283d91c0b748cc7",
    "zh:80607dfe5f7770d136d5c451308b9861084ffad08139de8014e48672ec43ea3f",
    "zh:863bf0a6576f7a969a89631525250d947fbb207d3d13e7ca4f74d86bd97cdda3",
    "zh:9a8f2e77e4f99dbb618eb8ad17218a4698833754b50d46da5727323a2050a400",
    "zh:9b12af85486a96aedd8d7984b0ff811a4b42e3d88dad1a3fb4c0b580d04fa425",
    "zh:9b74ff6e638c2a470b3599d57c2081e0095976da0a54b6590884d571f930b53b",
    "zh:da4fc553d50ae833d860ec95120e271c29b4cb636917ab5991327362b7486bb7",
    "zh:f4b86e7df4e846a38774e8e648b41c5ebaddcefa913cfa1864568086b7735575",
  ]
}



