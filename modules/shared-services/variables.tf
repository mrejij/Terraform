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
# SUBNET & IDENTITY REFERENCES
# ---------------------------------------------------------------------------------------------------------------------

variable "app_subnet_id" {
  description = "ID of the app subnet for private endpoints"
  type        = string
}

variable "managed_identity_principal_id" {
  description = "Principal ID of the shared managed identity"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# DNS ZONE REFERENCES
# ---------------------------------------------------------------------------------------------------------------------

variable "acr_private_dns_zone_id" {
  description = "ID of the privatelink.azurecr.io DNS zone"
  type        = string
}

variable "kv_private_dns_zone_id" {
  description = "ID of the privatelink.vaultcore.azure.net DNS zone"
  type        = string
}

variable "storage_blob_private_dns_zone_id" {
  description = "ID of the privatelink.blob.core.windows.net DNS zone"
  type        = string
}

variable "storage_file_private_dns_zone_id" {
  description = "ID of the privatelink.file.core.windows.net DNS zone"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# LOG ANALYTICS
# ---------------------------------------------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Log Analytics workspace data retention in days"
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------------------------------------------------
# STORAGE ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

variable "storage_replication_type" {
  description = "Storage account replication type (LRS, GRS, ZRS, GZRS)"
  type        = string
  default     = "LRS"
}

variable "file_share_names" {
  description = "List of file share names to create for pod data persistence"
  type        = list(string)
  default     = ["app-data", "jenkins-data", "shared-config"]
}

variable "file_share_quota_gb" {
  description = "Quota in GB for each file share"
  type        = number
  default     = 5
}
