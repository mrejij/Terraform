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

variable "aks_subnet_id" {
  description = "ID of the AKS subnet"
  type        = string
}

variable "aks_sp_client_id" {
  description = "Client ID of the AKS Service Principal"
  type        = string
  sensitive   = true
}

variable "aks_sp_client_secret" {
  description = "Client Secret of the AKS Service Principal"
  type        = string
  sensitive   = true
}

variable "aks_sp_object_id" {
  description = "Object ID of the AKS Service Principal (for role assignments)"
  type        = string
  sensitive   = true
}

variable "aks_private_dns_zone_id" {
  description = "ID of the AKS private DNS zone"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for monitoring"
  type        = string
}

variable "vnet_id" {
  description = "ID of the VNet (for Network Contributor role)"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# AKS CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 1
}

variable "system_node_vm_size" {
  description = "VM size for system node pool"
  type        = string
  default     = "Standard_D2ls_v5"
}

variable "worker_node_min_count" {
  description = "Minimum number of nodes in the worker pool (autoscaler lower bound)"
  type        = number
  default     = 2
}

variable "worker_node_max_count" {
  description = "Maximum number of nodes in the worker pool (autoscaler upper bound)"
  type        = number
  default     = 4
}

variable "worker_node_vm_size" {
  description = "VM size for worker node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_sku_tier" {
  description = "AKS SKU tier (Free or Standard)"
  type        = string
  default     = "Standard"
}

variable "service_cidr" {
  description = "CIDR range for Kubernetes services (must not overlap with VNet)"
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for the Kubernetes DNS service (must be within service_cidr)"
  type        = string
  default     = "172.16.0.10"
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 30
}

variable "tenant_id" {
  description = "Azure AD tenant ID for AKS RBAC"
  type        = string
}