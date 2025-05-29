# Outputs for Databricks Account Admin Module

# User Information
output "created_users" {
  description = "Map of created users with their IDs"
  value = {
    for email, user in databricks_user.unity_users : email => {
      id           = user.id
      user_name    = user.user_name
      display_name = user.display_name
    }
  }
}

output "account_admin_users" {
  description = "List of account admin user emails"
  value       = var.databricks_account_admins
}

output "regular_users" {
  description = "List of regular user emails"
  value       = var.databricks_users
}

# Group Information
output "admin_group" {
  description = "Admin group information"
  value = {
    id           = databricks_group.admin_group.id
    display_name = databricks_group.admin_group.display_name
  }
}

output "users_group" {
  description = "Users group information (if created)"
  value = length(databricks_group.users_group) > 0 ? {
    id           = databricks_group.users_group[0].id
    display_name = databricks_group.users_group[0].display_name
  } : null
}

# Service Principal Information
output "automation_service_principal" {
  description = "Automation service principal information (if created)"
  value = var.create_automation_service_principal ? {
    id             = databricks_service_principal.automation_sp[0].id
    display_name   = databricks_service_principal.automation_sp[0].display_name
    application_id = databricks_service_principal.automation_sp[0].application_id
  } : null
  sensitive = true
}

# Account Information
# output "current_user" {
#   description = "Information about the current authenticated user"
#   value = {
#     user_name = data.databricks_current_user.me.user_name
#     user_id   = data.databricks_current_user.me.id
#   }
# }

output "databricks_account_id" {
  description = "Databricks Account ID"
  value       = var.databricks_account_id
}

# Summary Information
output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    total_users_created       = length(databricks_user.unity_users)
    account_admins_count      = length(var.databricks_account_admins)
    regular_users_count       = length(var.databricks_users)
    admin_group_name          = databricks_group.admin_group.display_name
    users_group_created       = length(databricks_group.users_group) > 0
    service_principal_created = var.create_automation_service_principal
    environment               = var.environment
  }
}

# Next Steps Information
output "next_steps" {
  description = "Information about next steps for Unity Catalog setup"
  value = {
    message           = "Account admins have been successfully created and configured. You can now proceed to Stage 2 of Unity Catalog setup to create metastores and workspace-level resources."
    admin_group_id    = databricks_group.admin_group.id
    ready_for_stage_2 = true
  }
}