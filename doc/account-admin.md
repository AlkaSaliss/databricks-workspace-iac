# Account Admin Module

This Terraform module manages Databricks account-level administration tasks, including users, groups, and service principals. It is designed to set up the necessary account-level configurations before deploying Unity Catalog or workspaces.

## Purpose

- **User Management**: Creates and manages users at the Databricks account level. This includes regular users and users who will be designated as account administrators.
- **Group Management**: 
    - Creates an admin group (e.g., "Unity Catalog Admins") and adds specified account admins and the account owner to this group. This group is typically intended to own the Unity Catalog metastore.
    - Optionally creates a group for regular users.
- **Account Admin Roles**: Assigns the `account_admin` role to specified users, which is a prerequisite for them to create and manage metastores.
- **Service Principal Management** (Optional): Creates a service principal for automation purposes, grants it necessary permissions (cluster creation, instance pool creation), adds it to the admin group, and assigns it the `account_admin` role.

## Key Resources

- `databricks_user`: Manages users at the account level.
- `databricks_group`: Manages groups at the account level.
- `databricks_group_member`: Manages group memberships.
- `databricks_user_role`: Assigns account-level roles (like `account_admin`) to users.
- `databricks_service_principal`: Manages service principals for automation.
- `databricks_service_principal_role`: Assigns account-level roles to service principals.

## Variables

| Name                                  | Description                                                                                                 | Type          | Default                   | Required |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------- | ------------------------- | -------- |
| `databricks_client_id`                | Application ID of account-level service principal.                                                          | `string`      | -                         | Yes      |
| `databricks_client_secret`            | Client secret of account-level service principal.                                                           | `string`      | -                         | Yes      |
| `databricks_account_id`               | Databricks Account ID (must be a valid UUID format).                                                        | `string`      | -                         | Yes      |
| `databricks_users`                    | List of Databricks users to be added at account-level for Unity Catalog (e.g., `["user1@example.com"]`). | `list(string)`| `[]`                      | No       |
| `account_owner_email`                 | Email of the account owner.                                                                                 | `string`      | -                         | Yes      |
| `databricks_account_admins`           | List of Admins to be added at account-level for Unity Catalog (e.g., `["admin1@example.com"]`). At least one required. Do not include the account owner. | `list(string)`| -                         | Yes      |
| `user_display_names`                  | Map of user emails to display names.                                                                        | `map(string)` | `{}`                      | No       |
| `unity_admin_group`                   | Name of the admin group. This group will be set as the owner of the Unity Catalog metastore.                | `string`      | `"Unity Catalog Admins"`  | No       |
| `unity_users_group`                   | Name of the users group for regular Unity Catalog users.                                                    | `string`      | `"Unity Catalog Users"`   | No       |
| `create_automation_service_principal` | Whether to create a service principal for automation purposes.                                              | `bool`        | `false`                   | No       |
| `automation_service_principal_name`   | Name of the automation service principal.                                                                   | `string`      | `"terraform-automation-sp"` | No       |
| `environment`                         | Environment name (dev, staging, prod).                                                                      | `string`      | `"dev"`                   | No       |
| `additional_tags`                     | Additional tags to apply to all resources.                                                                  | `map(string)` | `{}`                      | No       |