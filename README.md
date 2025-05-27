# Databricks Workspace Infrastructure as Code

This repository contains Terraform and Terragrunt configurations to deploy a Databricks workspace on AWS with proper infrastructure setup.

## Architecture Overview

This implementation follows a standard Terragrunt "live" architecture:

```
.
├── terragrunt.hcl          # Global Terragrunt configuration
├── live/                   # Live environments
│   └── 123456789012/       # AWS Account ID (replace with yours)
│       └── us-east-1/      # AWS region (replace with yours)
│           ├── backend/    # S3 bucket and DynamoDB table for state
│           │   ├── main.tf
│           │   ├── variables.tf
│           │   ├── outputs.tf
│           │   └── terragrunt.hcl
│           └── databricks-workspace/ # Databricks workspace deployment
│               ├── main.tf
│               ├── variables.tf
│               ├── outputs.tf
│               └── terragrunt.hcl
├── modules/                # Reusable Terraform modules (optional)
└── doc/                    # Documentation
    └── infra-specification.md
```

## Prerequisites

1. **AWS Account** with administrative access
2. **Databricks Account** at `accounts.cloud.databricks.com`
3. **Terraform** installed (`terraform version`)
4. **Terragrunt** installed (`terragrunt --version`)
5. **AWS CLI** configured (`aws configure`)
6. **jq** installed (`brew install jq` on macOS)

## Initial Setup

### Step 1: Databricks Account Setup

1. Log in to [Databricks Account Console](https://accounts.cloud.databricks.com)
2. Note your **Account ID** from the homepage
3. Generate a **Personal Access Token (PAT)**:
   - Click your user icon → User Settings
   - Go to Access tokens tab
   - Click "Generate new token"
   - **Important**: Copy the token immediately - you won't see it again

### Step 2: AWS CLI Configuration

Configure a dedicated AWS profile for Terragrunt:

```bash
aws configure --profile default
```

Enter your AWS credentials with appropriate permissions (AdministratorAccess for this guide).

### Step 3: Update Configuration

1. **Update directory structure**: Replace `123456789012` with your actual AWS Account ID and `us-east-1` with your preferred region:

```bash
mv live/123456789012 live/YOUR_AWS_ACCOUNT_ID
mv live/YOUR_AWS_ACCOUNT_ID/us-east-1 live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION
```

2. **Update Databricks credentials** in `live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION/databricks-workspace/terragrunt.hcl`:

```hcl
inputs = {
  databricks_account_id = "your-actual-databricks-account-id"
  databricks_pat        = "your-actual-databricks-pat"
  workspace_name        = "my-databricks-workspace"
}
```

3. **Update backend configuration** in `live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION/backend/terragrunt.hcl`:

```hcl
locals {
  aws_account_id = "YOUR_AWS_ACCOUNT_ID"
  aws_region     = "YOUR_REGION"
}
```

### Step 4: Set AWS Profile

Export the AWS profile for Terragrunt to use:

```bash
export AWS_PROFILE=default
```

## Deployment

Navigate to your environment directory:

```bash
cd live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION
```

### Initialize

```bash
terragrunt run-all init
```

### Plan

```bash
terragrunt run-all plan
```

Review the planned changes carefully.

### Apply

```bash
terragrunt run-all apply
```

Type `yes` when prompted. The deployment will:
1. Create S3 bucket and DynamoDB table for state management
2. Deploy Databricks workspace with VPC, IAM roles, and networking (10-20 minutes)

## Verification

After deployment:

1. **Check outputs**: Note the `workspace_url` from the Terragrunt output
2. **Databricks Console**: Verify workspace appears in your account console
3. **AWS Console**: Check that VPC, S3 buckets, and IAM resources were created
4. **Access Workspace**: Use the `workspace_url` to log into your new workspace

## Infrastructure Components

### Backend Module
- S3 bucket for Terraform state storage
- DynamoDB table for state locking
- Proper encryption and access controls

### Databricks Workspace Module
- **Networking**: VPC with public/private subnets, NAT Gateway, Internet Gateway
- **IAM**: Roles and policies for Databricks service
- **Storage**: S3 bucket for Databricks root storage
- **Databricks Resources**: Credentials, storage configuration, network configuration, workspace

## Security Considerations

- **Sensitive Variables**: Never commit Databricks PAT or Account ID to version control
- **IAM Permissions**: The provided IAM policy is broad - restrict for production use
- **Network Security**: Private subnets isolate Databricks compute from public internet
- **Encryption**: S3 buckets use server-side encryption

## Cleanup

To destroy all resources:

```bash
cd live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION
terragrunt run-all destroy
```

Type `yes` when prompted. Resources will be destroyed in dependency order.

## Troubleshooting

### Common Issues

1. **AWS Profile**: Ensure `AWS_PROFILE` environment variable is set
2. **Permissions**: Verify AWS credentials have sufficient permissions
3. **Region**: Ensure availability zones exist in your chosen region
4. **Databricks Credentials**: Verify Account ID and PAT are correct

### Debug Individual Modules

If deployment fails, debug specific modules:

```bash
cd live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION/backend
terragrunt plan
# or
cd live/YOUR_AWS_ACCOUNT_ID/YOUR_REGION/databricks-workspace
terragrunt plan
```

## Customization

### Network Configuration

Modify CIDR blocks in `databricks-workspace/terragrunt.hcl`:

```hcl
inputs = {
  vpc_cidr_block = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}
```

### Resource Naming

The `prefix` variable (automatically generated) controls resource naming. Resources are named as:
- `dtb-{account-id}-{region}-{resource-type}`

## Cost Considerations

- **Databricks Workspace**: Charges apply for compute usage
- **AWS Resources**: NAT Gateway, EIP, and data transfer costs
- **S3 Storage**: Minimal costs for state and root storage
- **DynamoDB**: Pay-per-request pricing for state locking

Remember to destroy resources when not needed to avoid unnecessary costs.

## Support

For issues:
1. Check the [specification document](doc/infra-specification.md) for detailed explanations
2. Review Terraform and Terragrunt logs
3. Verify AWS and Databricks permissions
4. Ensure all prerequisites are met