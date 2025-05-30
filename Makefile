# Makefile for Databricks Workspace Infrastructure as Code
# Provides convenient commands for managing Terragrunt deployments

.PHONY: help init plan apply destroy validate fmt lint clean check-env

# Default environment and region
ENV ?= dev
REGION ?= eu-west-1
COMPONENT ?= account-admin

# Source directory
SRC_DIR = src

# Paths
ENV_PATH = $(SRC_DIR)/environments/$(ENV)/$(REGION)

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Databricks Workspace Infrastructure as Code$(NC)"
	@echo "$(BLUE)===========================================$(NC)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Environment variables:$(NC)"
	@echo "  $(GREEN)ENV$(NC)                     Environment (default: dev)"
	@echo "  $(GREEN)REGION$(NC)                  AWS Region (default: eu-west-1)"
	@echo "  $(GREEN)COMPONENT$(NC)               Component to deploy (default: account-admin)"
	@echo "  $(GREEN)DATABRICKS_ACCOUNT_ID$(NC)   (Required) Databricks Account ID"
	@echo "  $(GREEN)DATABRICKS_CLIENT_ID$(NC)    (Required) Databricks Client ID for account auth"
	@echo "  $(GREEN)DATABRICKS_CLIENT_SECRET$(NC)(Required) Databricks Client Secret for account auth"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make init ENV=dev REGION=eu-west-1 COMPONENT=account-admin"
	@echo "  make plan COMPONENT=uc-aws-infra"
	@echo "  make apply COMPONENT=account-admin"

check-env: ## Check required environment variables for Databricks authentication
	@echo "$(BLUE)Checking environment variables...$(NC)"
	@if [ -z "$$DATABRICKS_ACCOUNT_ID" ]; then \
		echo "$(RED)Error: DATABRICKS_ACCOUNT_ID is not set$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$$DATABRICKS_CLIENT_ID" ]; then \
		echo "$(RED)Error: DATABRICKS_CLIENT_ID is not set$(NC)"; \
		exit 1; \
	fi
	@if [ -z "$$DATABRICKS_CLIENT_SECRET" ]; then \
		echo "$(RED)Error: DATABRICKS_CLIENT_SECRET is not set$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)All required Databricks environment variables are set$(NC)"

init: ## Initialize Terragrunt for the specified component
	@echo "$(BLUE)Initializing $(COMPONENT) in $(ENV)/$(REGION)...$(NC)"
	@cd $(ENV_PATH)/$(COMPONENT) && terragrunt init

plan: check-env ## Plan Terragrunt deployment for the specified component
	@echo "$(BLUE)Planning $(COMPONENT) in $(ENV)/$(REGION)...$(NC)"
	@cd $(ENV_PATH)/$(COMPONENT) && terragrunt plan

apply: check-env ## Apply Terragrunt deployment for the specified component
	@echo "$(BLUE)Applying $(COMPONENT) in $(ENV)/$(REGION)...$(NC)"
	@cd $(ENV_PATH)/$(COMPONENT) && terragrunt apply

destroy: check-env ## Destroy Terragrunt deployment for the specified component
	@echo "$(RED)Destroying $(COMPONENT) in $(ENV)/$(REGION)...$(NC)"
	@echo "$(YELLOW)WARNING: This will destroy infrastructure!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(ENV_PATH)/$(COMPONENT) && terragrunt destroy; \
	else \
		echo "$(GREEN)Cancelled$(NC)"; \
	fi

validate: ## Validate Terraform configuration for the specified component
	@echo "$(BLUE)Validating $(COMPONENT) in $(ENV)/$(REGION)...$(NC)"
	@cd $(ENV_PATH)/$(COMPONENT) && terragrunt validate

fmt: ## Format Terraform and Terragrunt files
	@echo "$(BLUE)Formatting HCL files...$(NC)"
	@terragrunt hclfmt --terragrunt-working-dir $(SRC_DIR)
	@find $(SRC_DIR) -name "*.tf" -exec terraform fmt {} \;
	@echo "$(GREEN)Formatting complete.$(NC)"

lint: ## Lint Terraform files
	@echo "$(BLUE)Linting Terraform files...$(NC)"
	@find $(SRC_DIR) -name "*.tf" -exec terraform fmt -check {} \;
	@echo "$(GREEN)Linting complete.$(NC)"

clean: ## Clean Terragrunt cache and .terraform directories
	@echo "$(BLUE)Cleaning Terragrunt cache...$(NC)"
	@find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Cache cleaned$(NC)"

# Bootstrap commands
bootstrap-admin: check-env ## Bootstrap account admin setup
	@echo "$(BLUE)Bootstrapping account admin...$(NC)"
	@$(MAKE) init COMPONENT=account-admin
	@$(MAKE) apply COMPONENT=account-admin

bootstrap-uc-aws: check-env ## Bootstrap Unity Catalog AWS resources (now uc-aws-infra)
	@echo "$(BLUE)Bootstrapping Unity Catalog AWS resources (uc-aws-infra)...$(NC)"
	@$(MAKE) init COMPONENT=uc-aws-infra
	@$(MAKE) apply COMPONENT=uc-aws-infra

bootstrap: bootstrap-admin bootstrap-uc-aws ## Bootstrap admin and Unity Catalog AWS infrastructure
	@echo "$(GREEN)Bootstrap for account-admin and uc-aws-infra complete!$(NC)"

# Development setup and commands (example for account-admin and uc-aws-infra)
dev-setup: ## Set up development environment (copy .tfvars.example files)
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@if [ ! -f "$(ENV_PATH)/account-admin/terraform.tfvars" ] && [ -f "$(ENV_PATH)/account-admin/terraform.tfvars.example" ]; then \
		cp "$(ENV_PATH)/account-admin/terraform.tfvars.example" "$(ENV_PATH)/account-admin/terraform.tfvars"; \
		echo "$(YELLOW)Created $(ENV_PATH)/account-admin/terraform.tfvars from example. Please update with your values.$(NC)"; \
	else \
		echo "$(GREEN)$(ENV_PATH)/account-admin/terraform.tfvars already exists or example missing$(NC)"; \
	fi
	@if [ ! -f "$(ENV_PATH)/uc-aws-infra/terraform.tfvars" ] && [ -f "$(ENV_PATH)/uc-aws-infra/terraform.tfvars.example" ]; then \
		cp "$(ENV_PATH)/uc-aws-infra/terraform.tfvars.example" "$(ENV_PATH)/uc-aws-infra/terraform.tfvars"; \
		echo "$(YELLOW)Created $(ENV_PATH)/uc-aws-infra/terraform.tfvars from example. Please update with your values.$(NC)"; \
	else \
		echo "$(GREEN)$(ENV_PATH)/uc-aws-infra/terraform.tfvars already exists or example missing$(NC)"; \
	fi

# Per-component dev commands
dev-account-admin-plan: ## Plan account-admin in dev environment
	@$(MAKE) plan ENV=dev REGION=$(REGION) COMPONENT=account-admin
dev-account-admin-apply: ## Apply account-admin in dev environment
	@$(MAKE) apply ENV=dev REGION=$(REGION) COMPONENT=account-admin
dev-account-admin-destroy: ## Destroy account-admin in dev environment
	@$(MAKE) destroy ENV=dev REGION=$(REGION) COMPONENT=account-admin

dev-uc-aws-infra-plan: ## Plan uc-aws-infra in dev environment
	@$(MAKE) plan ENV=dev REGION=$(REGION) COMPONENT=uc-aws-infra
dev-uc-aws-infra-apply: ## Apply uc-aws-infra in dev environment
	@$(MAKE) apply ENV=dev REGION=$(REGION) COMPONENT=uc-aws-infra
dev-uc-aws-infra-destroy: ## Destroy uc-aws-infra in dev environment
	@$(MAKE) destroy ENV=dev REGION=$(REGION) COMPONENT=uc-aws-infra

# Aggregated dev commands
dev-plan-all: dev-account-admin-plan dev-uc-aws-infra-plan ## Plan all components in dev
	@echo "$(GREEN)All dev components planned.$(NC)"
dev-apply-all: dev-account-admin-apply dev-uc-aws-infra-apply ## Apply all components in dev
	@echo "$(GREEN)All dev components applied.$(NC)"
dev-destroy-all: dev-uc-aws-infra-destroy dev-account-admin-destroy ## Destroy all components in dev (reverse order)
	@echo "$(GREEN)All dev components destroyed.$(NC)"

# Utility commands
show-config: ## Show current configuration
	@echo "$(BLUE)Current Configuration:$(NC)"
	@echo "  Environment: $(GREEN)$(ENV)$(NC)"
	@echo "  Region:      $(GREEN)$(REGION)$(NC)"
	@echo "  Component:   $(GREEN)$(COMPONENT)$(NC)"
	@echo "  Path:        $(GREEN)$(ENV_PATH)/$(COMPONENT)$(NC)"

list-envs: ## List available environments
	@echo "$(BLUE)Available environments (looking for env.hcl in $(SRC_DIR)/environments):$(NC)"
	@find $(SRC_DIR)/environments -mindepth 1 -maxdepth 1 -type d -exec test -f {}/env.hcl \; -print | sed 's|$(SRC_DIR)/environments/||' | sort

list-components: ## List available components for current environment and region
	@echo "$(BLUE)Available components in $(ENV)/$(REGION) (under $(ENV_PATH)):$(NC)"
	@if [ -d "$(ENV_PATH)" ]; then \
		ls -1 "$(ENV_PATH)" | grep -v "region.hcl" | grep -v "env.hcl" | sort; \
	else \
		echo "$(RED)Environment path $(ENV_PATH) not found$(NC)"; \
	fi

# Documentation
docs: ## Generate documentation for modules
	@echo "$(BLUE)Generating documentation...$(NC)"
	@terraform-docs markdown table --output-file $(SRC_DIR)/modules/account-admin/README.md $(SRC_DIR)/modules/account-admin/
	@terraform-docs markdown table --output-file $(SRC_DIR)/modules/terraform-state-infra/README.md $(SRC_DIR)/modules/terraform-state-infra/
	@terraform-docs markdown table --output-file $(SRC_DIR)/modules/uc-aws-infra/README.md $(SRC_DIR)/modules/uc-aws-infra/
	@echo "$(GREEN)Documentation generated in module README.md files$(NC)"

# Version information
version: ## Show version information for key tools
	@echo "$(BLUE)Version Information:$(NC)"
	@echo -n "  Terraform:  "; terraform version | head -n1
	@echo -n "  Terragrunt: "; terragrunt --version | head -n1
	@echo -n "  AWS CLI:    "; aws --version 2>&1 | cut -d' ' -f1

# Default target
.DEFAULT_GOAL := help