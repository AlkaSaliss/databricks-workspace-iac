Directory structure:
└── aws-databricks-uc-bootstrap/
    ├── README.md
    ├── main.tf
    ├── terraform.tfvars
    ├── variables.tf
    └── .terraform.lock.hcl

================================================
File: README.md
================================================
AWS Databricks Unity Catalog - Stage 1
=========================

In this template, we show a simple process to deploy Unity Catalog account level resources and infra into modules and manage your account level resources, metastores, users and groups. For Databricks official terraform samples, please refer to [Databricks Terraform Samples](
https://github.com/databricks/unity-catalog-setup)

## Context

[What is Unity Catalog?](https://docs.databricks.com/data-governance/unity-catalog/index.html)

[Terraform Guide - Set up Unity Catalog on AWS](https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog)

## Getting Started

AWS Databricks has 2 levels of resources:
1. Account Level (unity metastore, account level users/groups, etc)
2. Workspace Level (workspace level users/groups, workspace objects like clusters)

The 2 levels of resources use different providers configs and have different authentication method, client ID/client secret is the only method for account level provider authentication. 

For workspace level provider you can create `n` databricks providers for `n` existing workspaces, each provider to be authenticate via PAT token.

We propose 2-stage process to get onboarded to UC. Starting at the point where you only have `account owner`, and this identity will also be the first `account admin`. Account admins can add/remove other account admins, including service principals.

We recommend using `account admin` identities to deploy unity catalog related resources.

> In stage 1, you use `account owner` to create `account admins`, this can be done in either method below:
> 1. Use this folder, authenticate the `mws` provider with `account owner`, and supply `account admin` in `terraform.tfvars`, do not put `account owner` into the admin list since we do not want terraform to manage `account owner`.
> 2. You can manually create `account admin` on [account console](accounts.cloud.databricks.com) UI. 
>
> In stage 2, you use the newly created account admin identity to authenticate the `databricks mws` provider, and create the unity catalog related resources, using example scripts in `aws_databricks_unity_catalog`.

Refer to below diagram on the process.

![alt text](https://raw.githubusercontent.com/databricks/terraform-databricks-examples/main/examples/aws-databricks-uc/images/uc-tf-onboarding.png?raw=true)

## How to fill `terraform.tfvars`

databricks_users          = [] (you can leave this as empty list)

databricks_account_admins = ["hao.wang@databricks.com"] (do not put account owner in this list, add emails of the account admins)

unity_admin_group         = " Bootstrap admin group" (this is the display name of the admin group)

## Expected Outcome

After running this template using `terraform init` and `terraform apply` with your provided list of account admins, you should see account admins' emails under the newly created group, thus you have successfully onboarded account admins identity to your Databricks Account. 

![alt text](https://raw.githubusercontent.com/databricks/terraform-databricks-examples/main/examples/aws-databricks-uc/images/uc-tf-account-admin.png?raw=true)

Now you can proceed to stage 2, navigate to [aws_databricks_unity_catalog](https://github.com/hwang-db/tf_aws_deployment/tree/main/aws_databricks_unity_catalog) for stage 2 deployments.



================================================
File: main.tf
================================================
terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id // like a shared account? HA from multiple email accounts
  client_id     = var.databricks_account_client_id
  client_secret = var.databricks_account_client_secret
  auth_type     = "oauth-m2m"
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


resource "databricks_user_role" "account_admin_role" { // this group is admin for metastore, also pre-requisite for creating metastore
  provider = databricks.mws
  for_each = toset(var.databricks_account_admins)
  user_id  = databricks_user.unity_users[each.value].id
  role     = "account_admin"
}



================================================
File: terraform.tfvars
================================================
databricks_users          = []
databricks_account_admins = ["hao.wang@databricks.com"] // use UI to remove account owner, then remove account owner from this list
unity_admin_group         = " Bootstrap admin group"



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

variable "databricks_users" {
  description = <<EOT
  List of Databricks users to be added at account-level for Unity Catalog.
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



================================================
File: .terraform.lock.hcl
================================================
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/databricks/databricks" {
  version = "1.4.0"
  hashes = [
    "h1:3OCWMGCeWNBdVSWjmnvBjwQoiIgqgwd+A1mL3lTNLfA=",
    "zh:553e2ea0d23e75d1e49f384aadfb9793920784aef744fa1cbf0eb8ca4c8e3e7f",
    "zh:7d133069ed43e8815bb325dc6492e617762bfa7557ba82b3732db17a8789c0af",
    "zh:859d90a03d2c54391836c12f1f374bf65be0ce5d35814941436149c705ed16f3",
    "zh:a94b19f78cf3110a5076ff5051a9024dde6965b5e18ad68846f591404908b7f5",
    "zh:b9bbff940bf4a6befae4022b08a757d7340613b202a4f9bc5209da3ab79bcf01",
    "zh:bdf4ddd9c9d338330428afa75395629db198509fe0887eb387ba47bfe2f56e2c",
    "zh:d41cd8db72da49697499761b8bb95c733e9d4c6f76311199f04390ddac257dd2",
    "zh:d92795d8464603ab2d6810c48eaf8a8106dac2602a8cbafb6f7fc978129bf0c7",
    "zh:e4e39471579aeb0abbcbb83f8a541ea881af1e8fe13e927e21ca15998767beb8",
    "zh:f3767419522823d9ebb25bfbeaff8a98e57677019210ec1a4964ded9660d7043",
  ]
}


