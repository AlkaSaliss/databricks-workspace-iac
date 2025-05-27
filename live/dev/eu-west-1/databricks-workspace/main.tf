# live/dev/eu-west-1/databricks-workspace/main.tf

# Configure the AWS provider
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Configure the Databricks provider
provider "databricks" {
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
  token      = var.databricks_pat
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
  domain     = "vpc"
  depends_on = [aws_internet_gateway.databricks_igw]

  tags = {
    Name = "${var.prefix}-databricks-nat-eip"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.databricks_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = "${var.aws_region}${element(["a", "b"], count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-public-subnet-${element(["a", "b"], count.index)}"
  }
}

resource "aws_nat_gateway" "databricks_nat_gateway" {
  allocation_id = aws_eip.databricks_nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

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
  availability_zone = "${var.aws_region}${element(["a", "b"], count.index)}"

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
        Resource = "*"
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
        Resource = "*"
      },
      {
        Action = [
          "iam:CreateInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile", "iam:GetInstanceProfile", "iam:ListInstanceProfiles", "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sts:AssumeRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:CreateGrant",
          "kms:ListGrants", "kms:RevokeGrant", "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = "*"
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

# --- S3 Bucket for Databricks Root Storage ---

resource "aws_s3_bucket" "databricks_root_bucket" {
  bucket = "${var.prefix}-${var.workspace_name}-root-bucket-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.prefix}-databricks-root-bucket"
    Environment = "Databricks"
  }
}

resource "aws_s3_bucket_versioning" "databricks_root_bucket_versioning" {
  bucket = aws_s3_bucket.databricks_root_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "databricks_root_bucket_encryption" {
  bucket = aws_s3_bucket.databricks_root_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "databricks_root_bucket_block" {
  bucket = aws_s3_bucket.databricks_root_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Databricks Workspace Deployment ---

resource "databricks_mws_credentials" "this" {
  account_id       = var.databricks_account_id
  credentials_name = "${var.prefix}-${var.workspace_name}-credentials"
  role_arn         = aws_iam_role.databricks_workspace_role.arn
}

resource "databricks_mws_storage_configuration" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${var.prefix}-${var.workspace_name}-storage"
  bucket_name                = aws_s3_bucket.databricks_root_bucket.bucket
}

resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = "${var.prefix}-${var.workspace_name}-network"
  vpc_id             = aws_vpc.databricks_vpc.id
  subnet_ids         = aws_subnet.private_subnets[*].id
  security_group_ids = []
}

resource "databricks_mws_workspace" "this" {
  account_id               = var.databricks_account_id
  aws_region               = var.aws_region
  workspace_name           = var.workspace_name
  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configuration.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}

# Data source to get current AWS account ID for unique S3 bucket name
data "aws_caller_identity" "current" {}