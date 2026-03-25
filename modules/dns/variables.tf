variable "project" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region (used for AKS private DNS zone name)"
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

variable "virtual_network_id" {
  description = "ID of the virtual network to link DNS zones to"
  type        = string
}

variable "private_dns_zone_names" {
  description = "List of private DNS zone names for Azure services"
  type        = list(string)
  default = [
    "privatelink.azurecr.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.database.windows.net",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net"
  ]
}

variable "internal_dns_zone_name" {
  description = "Custom internal DNS zone for service discovery (nginx ingress)"
  type        = string
  default     = "svc.cluster.internal"
}
