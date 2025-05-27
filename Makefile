# Makefile for Databricks Workspace Infrastructure

.PHONY: help check init plan deploy destroy clean format validate

# Default target
help:
	@echo "Databricks Workspace Infrastructure Management"
	@echo ""
	@echo "Available targets:"
	@echo "  help      - Show this help message"
	@echo "  check     - Check prerequisites and configuration"
	@echo "  init      - Initialize Terragrunt modules"
	@echo "  plan      - Plan the deployment"
	@echo "  deploy    - Deploy the infrastructure"
	@echo "  destroy   - Destroy the infrastructure"
	@echo "  format    - Format Terraform files"
	@echo "  validate  - Validate Terraform configuration"
	@echo "  clean     - Clean Terragrunt cache"
	@echo ""
	@echo "Environment Variables:"
	@echo "  AWS_PROFILE - AWS profile to use (default: default)"
	@echo "  LIVE_DIR    - Live directory path (auto-detected if not set)"

# Find the live directory
LIVE_DIR ?= $(shell find live -name "*.hcl" -path "*/backend/terragrunt.hcl" | head -1 | xargs dirname | xargs dirname)

# Check if live directory exists
check-live-dir:
	@if [ -z "$(LIVE_DIR)" ] || [ ! -d "$(LIVE_DIR)" ]; then \
		echo "Error: Live directory not found. Please ensure you have the correct directory structure."; \
		exit 1; \
	fi
	@echo "Using live directory: $(LIVE_DIR)"

# Check prerequisites
check:
	@./deploy.sh check

# Initialize Terragrunt
init: check-live-dir
	@echo "Initializing Terragrunt in $(LIVE_DIR)..."
	@cd $(LIVE_DIR) && terragrunt run-all init

# Plan deployment
plan: check-live-dir
	@echo "Planning deployment in $(LIVE_DIR)..."
	@cd $(LIVE_DIR) && terragrunt run-all plan

# Deploy infrastructure
deploy:
	@./deploy.sh deploy

# Destroy infrastructure
destroy:
	@./deploy.sh destroy

# Format Terraform files
format:
	@echo "Formatting Terraform files..."
	@find . -name "*.tf" -exec terraform fmt {} \;
	@find . -name "*.hcl" -exec terragrunt hclfmt {} \;

# Validate Terraform configuration
validate: check-live-dir
	@echo "Validating Terraform configuration in $(LIVE_DIR)..."
	@cd $(LIVE_DIR) && terragrunt run-all validate

# Clean Terragrunt cache
clean:
	@echo "Cleaning Terragrunt cache..."
	@find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cache cleaned."

# Show current configuration
show-config: check-live-dir
	@echo "Current configuration:"
	@echo "  Live directory: $(LIVE_DIR)"
	@echo "  AWS Profile: $${AWS_PROFILE:-default}"
	@if [ -f "$(LIVE_DIR)/databricks-workspace/terragrunt.hcl" ]; then \
		echo "  Workspace config found: ✓"; \
	else \
		echo "  Workspace config found: ✗"; \
	fi
	@if [ -f "$(LIVE_DIR)/backend/terragrunt.hcl" ]; then \
		echo "  Backend config found: ✓"; \
	else \
		echo "  Backend config found: ✗"; \
	fi