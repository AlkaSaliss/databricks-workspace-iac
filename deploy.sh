#!/bin/bash

# Databricks Workspace Deployment Script
# This script helps deploy the Databricks workspace infrastructure using Terragrunt

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists terragrunt; then
        missing_tools+=("terragrunt")
    fi
    
    if ! command_exists aws; then
        missing_tools+=("aws")
    fi
    
    if ! command_exists jq; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed."
}

# Check AWS profile
check_aws_profile() {
    print_status "Checking AWS configuration..."
    
    if [ -z "$AWS_PROFILE" ]; then
        print_warning "AWS_PROFILE environment variable not set."
        print_status "Setting AWS_PROFILE to 'default'"
        export AWS_PROFILE=default
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid."
        print_error "Please run 'aws configure --profile $AWS_PROFILE' and try again."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS configured. Account ID: $account_id"
}

# Find live directory
find_live_directory() {
    print_status "Looking for live environment directory..."
    
    local live_dirs=(live/*/)
    if [ ${#live_dirs[@]} -eq 0 ] || [ ! -d "${live_dirs[0]}" ]; then
        print_error "No live environment directory found."
        print_error "Please ensure you have a directory structure like live/123456789012/us-east-1/"
        exit 1
    fi
    
    # Find the first region directory
    local region_dirs=("${live_dirs[0]}"*/)
    if [ ${#region_dirs[@]} -eq 0 ] || [ ! -d "${region_dirs[0]}" ]; then
        print_error "No region directory found in ${live_dirs[0]}"
        exit 1
    fi
    
    LIVE_DIR="${region_dirs[0]}"
    print_success "Found live directory: $LIVE_DIR"
}

# Check configuration
check_configuration() {
    print_status "Checking configuration..."
    
    local workspace_config="$LIVE_DIR/databricks-workspace/terragrunt.hcl"
    
    if [ ! -f "$workspace_config" ]; then
        print_error "Workspace configuration not found: $workspace_config"
        exit 1
    fi
    
    # Check for placeholder values
    if grep -q "YOUR_DATABRICKS_ACCOUNT_ID" "$workspace_config"; then
        print_error "Please update the Databricks Account ID in $workspace_config"
        exit 1
    fi
    
    if grep -q "YOUR_DATABRICKS_PAT" "$workspace_config"; then
        print_error "Please update the Databricks PAT in $workspace_config"
        exit 1
    fi
    
    print_success "Configuration looks good."
}

# Deploy infrastructure
deploy() {
    print_status "Starting deployment..."
    
    cd "$LIVE_DIR"
    
    print_status "Initializing Terragrunt..."
    if ! terragrunt run-all init; then
        print_error "Terragrunt initialization failed."
        exit 1
    fi
    
    print_status "Planning deployment..."
    if ! terragrunt run-all plan; then
        print_error "Terragrunt planning failed."
        exit 1
    fi
    
    print_warning "Review the plan above carefully."
    read -p "Do you want to proceed with the deployment? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    print_status "Applying deployment..."
    if ! terragrunt run-all apply; then
        print_error "Terragrunt apply failed."
        exit 1
    fi
    
    print_success "Deployment completed successfully!"
}

# Destroy infrastructure
destroy() {
    print_status "Starting destruction..."
    
    cd "$LIVE_DIR"
    
    print_warning "This will destroy ALL infrastructure in $LIVE_DIR"
    read -p "Are you sure you want to destroy all resources? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Destruction cancelled."
        exit 0
    fi
    
    print_status "Destroying infrastructure..."
    if ! terragrunt run-all destroy; then
        print_error "Terragrunt destroy failed."
        exit 1
    fi
    
    print_success "Infrastructure destroyed successfully!"
}

# Show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy the Databricks workspace infrastructure"
    echo "  destroy   Destroy the Databricks workspace infrastructure"
    echo "  check     Check prerequisites and configuration"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_PROFILE    AWS profile to use (default: default)"
}

# Main script
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            check_aws_profile
            find_live_directory
            check_configuration
            deploy
            ;;
        "destroy")
            check_prerequisites
            check_aws_profile
            find_live_directory
            destroy
            ;;
        "check")
            check_prerequisites
            check_aws_profile
            find_live_directory
            check_configuration
            print_success "All checks passed!"
            ;;
        "help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"