provider "databricks" {
  alias = "account"
  # Configuration attributes (host, account_id, etc.) are typically
  # inherited from the root module's provider configuration
  # when using Terragrunt, or defined in the backend block.
  # No explicit configuration needed here if managed by Terragrunt/root.
}