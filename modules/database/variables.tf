variable "project" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "location_short" {
  description = "Short form of Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# REFERENCES
# ---------------------------------------------------------------------------------------------------------------------

variable "database_subnet_id" {
  description = "ID of the database subnet for private endpoint"
  type        = string
}

variable "managed_identity_id" {
  description = "ID of the user-assigned managed identity"
  type        = string
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the managed identity (for AAD admin)"
  type        = string
}

variable "sql_private_dns_zone_id" {
  description = "ID of the privatelink.database.windows.net DNS zone"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault for storing secrets"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# SQL SERVER CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "sql_admin_username" {
  description = "SQL Server administrator login name"
  type        = string
  default     = "sqladmin"
}

variable "sql_database_max_size_gb" {
  description = "Maximum size of the SQL database in GB"
  type        = number
  default     = 2
}

variable "sql_database_sku" {
  description = "SKU name for the SQL Database (e.g., Basic, S0, S1, P1, GP_S_Gen5_2)"
  type        = string
  default     = "Basic"
}

variable "sql_zone_redundant" {
  description = "Enable zone redundancy for the SQL Database"
  type        = bool
  default     = false
}

variable "sql_backup_retention_days" {
  description = "Short-term backup retention in days (7-35)"
  type        = number
  default     = 7
}

variable "aad_admin_login" {
  description = "Azure AD admin login display name for SQL Server"
  type        = string
  default     = "sqlaadadmin"
}
