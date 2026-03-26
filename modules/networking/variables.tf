# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "project" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "location_short" {
  description = "Short form of Azure region (e.g., eus for eastus)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "database_subnet_address_prefix" {
  description = "Address prefix for database subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "app_subnet_address_prefix" {
  description = "Address prefix for application subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "bastion_subnet_address_prefix" {
  description = "Address prefix for Azure Bastion subnet (minimum /26)"
  type        = string
  default     = "10.0.4.0/26"
}

variable "deployer_ip" {
  description = "Public IP of the deployer for SSH and Jenkins access (CIDR format, e.g. 1.2.3.4/32). Leave empty to skip deployer NSG rules."
  type        = string
  default     = ""
}
