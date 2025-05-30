# Unity Catalog AWS Infrastructure Module
# This module creates the complete AWS infrastructure required for Databricks Unity Catalog

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  metastore_name = var.metastore_name == null ? "${var.prefix}-metastore" : var.metastore_name
  iam_role_name  = "${var.prefix}-unity-catalog-metastore-access"
  iam_role_arn   = "arn:aws:iam::${local.aws_account_id}:role/${local.iam_role_name}"
}

# VPC Module for Databricks Workspace
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.0"

  name = var.prefix
  cidr = var.cidr_block
  azs  = data.aws_availability_zones.available.names
  tags = var.tags

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  create_igw           = true

  public_subnets = [cidrsubnet(var.cidr_block, 3, 0)]
  private_subnets = [
    cidrsubnet(var.cidr_block, 3, 1),
    cidrsubnet(var.cidr_block, 3, 2)
  ]

  manage_default_security_group = true
  default_security_group_name   = "${var.prefix}-sg"

  default_security_group_egress = [{
    cidr_blocks = "0.0.0.0/0"
  }]

  default_security_group_ingress = [{
    description = "Allow all internal TCP and UDP"
    self        = true
  }]
}

# VPC Endpoints for Databricks
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.7.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids
      ])
      tags = {
        Name = "${var.prefix}-s3-vpc-endpoint"
      }
    },
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name = "${var.prefix}-sts-vpc-endpoint"
      }
    },
    kinesis-streams = {
      service             = "kinesis-streams"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name = "${var.prefix}-kinesis-vpc-endpoint"
      }
    },
  }

  tags = var.tags
}

# S3 Bucket for Databricks Root Storage
resource "aws_s3_bucket" "root_storage_bucket" {
  bucket        = "${var.prefix}-rootbucket"
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${var.prefix}-rootbucket"
  })
}

resource "aws_s3_bucket_versioning" "root_storage_versioning" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "root_storage_bucket" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "root_storage_bucket" {
  bucket                  = aws_s3_bucket.root_storage_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.root_storage_bucket]
}

data "databricks_aws_bucket_policy" "root_bucket" {
  provider = databricks.mws
  bucket   = aws_s3_bucket.root_storage_bucket.bucket
}

resource "aws_s3_bucket_policy" "root_bucket_policy" {
  bucket     = aws_s3_bucket.root_storage_bucket.id
  policy     = data.databricks_aws_bucket_policy.root_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.root_storage_bucket]
}

# S3 Bucket for Unity Catalog Metastore
resource "aws_s3_bucket" "metastore" {
  bucket        = "${var.prefix}-metastore"
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${var.prefix}-metastore"
  })
}

resource "aws_s3_bucket_versioning" "metastore_versioning" {
  bucket = aws_s3_bucket.metastore.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metastore" {
  bucket = aws_s3_bucket.metastore.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "metastore" {
  bucket                  = aws_s3_bucket.metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.metastore]
}

# Cross-account role for Databricks workspace
data "databricks_aws_assume_role_policy" "this" {
  provider    = databricks.mws
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account_role" {
  name               = "${var.prefix}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}

data "databricks_aws_crossaccount_policy" "this" {
  provider = databricks.mws
}

data "aws_iam_policy_document" "cross_account_policy" {
  source_policy_documents = [data.databricks_aws_crossaccount_policy.this.json]

  statement {
    sid       = "allowPassCrossServiceRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.iam_role_arn]
  }
}

resource "aws_iam_role_policy" "cross_account_policy" {
  name   = "${var.prefix}-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = data.aws_iam_policy_document.cross_account_policy.json
}

# Unity Catalog IAM Role and Policies
data "aws_iam_policy_document" "passrole_for_uc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = [
        "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
      ]
      type = "AWS"
    }
    # Note: External ID condition will be managed by Databricks after role creation
    # Removing the condition to break the circular dependency
  }

  statement {
    sid     = "ExplicitSelfRoleAssumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.aws_account_id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = [local.iam_role_arn]
    }
  }
}

resource "aws_iam_policy" "unity_metastore" {
  name = "${var.prefix}-unity-catalog-metastore-access-iam-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.prefix}-databricks-unity-metastore"
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
        "Resource" : [local.iam_role_arn],
        "Effect" : "Allow"
      }
    ]
  })
  tags = merge(var.tags, {
    Name = "${local.iam_role_name} IAM policy"
  })
}

resource "aws_iam_policy" "sample_data" {
  name = "${var.prefix}-unity-catalog-sample-data-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.prefix}-databricks-sample-data"
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
    Name = "${var.prefix}-unity-catalog IAM policy"
  })
}

resource "aws_iam_role" "metastore_data_access" {
  name                = local.iam_role_name
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_uc.json
  managed_policy_arns = [aws_iam_policy.unity_metastore.arn, aws_iam_policy.sample_data.arn]
  tags = merge(var.tags, {
    Name = local.iam_role_name
  })
}

# Databricks Workspace Configuration
resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    aws_iam_role_policy.cross_account_policy
  ]
  create_duration = "30s" # Adjust as needed, 30 seconds is a common starting point
}

resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  account_id       = var.databricks_account_id
  role_arn         = aws_iam_role.cross_account_role.arn
  credentials_name = "${var.prefix}-creds"
  depends_on       = [time_sleep.wait_for_iam_propagation]
}

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${var.prefix}-network"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  bucket_name                = aws_s3_bucket.root_storage_bucket.bucket
  storage_configuration_name = "${var.prefix}-storage"
}

resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.databricks_account_id
  aws_region     = var.region
  workspace_name = coalesce(var.workspace_name, var.prefix)

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}

# Unity Catalog Metastore
resource "databricks_metastore" "this" {
  provider      = databricks.mws
  name          = local.metastore_name
  region        = var.region
  owner         = var.unity_metastore_owner
  storage_root  = "s3://${aws_s3_bucket.metastore.id}/metastore"
  force_destroy = true
}

# resource "databricks_metastore_data_access" "this" {
#   provider     = databricks.mws
#   metastore_id = databricks_metastore.this.id
#   name         = local.iam_role_name
#   aws_iam_role {
#     role_arn = local.iam_role_arn
#   }
#   is_default = true
#   depends_on = [aws_iam_role.metastore_data_access]
# }

resource "databricks_metastore_assignment" "default_metastore" {
  provider             = databricks.mws
  workspace_id         = databricks_mws_workspaces.this.workspace_id
  metastore_id         = databricks_metastore.this.id
  default_catalog_name = "hive_metastore"
}

resource "databricks_mws_permission_assignment" "add_ws_admin_group" {
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = var.admin_group_id
  permissions  = ["ADMIN"]
}

data "databricks_user" "ws_user_data" {
  for_each  = toset(var.ws_users)
  user_name = each.value
  provider  = databricks.mws
}

resource "databricks_mws_permission_assignment" "assign_ws_users" {
  for_each     = data.databricks_user.ws_user_data
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = each.value.id
  permissions  = ["USER"]
}
