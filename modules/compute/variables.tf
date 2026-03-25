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

variable "app_subnet_id" {
  description = "ID of the app subnet where VMs will be deployed"
  type        = string
}

variable "managed_identity_id" {
  description = "ID of the user-assigned managed identity"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault for storing secrets"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# LINUX VM CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "linux_vm_size" {
  description = "VM size for the Linux build server"
  type        = string
  default     = "Standard_B2s"
}

variable "linux_admin_username" {
  description = "Admin username for the Linux VM"
  type        = string
  default     = "azureadmin"
}

variable "linux_os_disk_size_gb" {
  description = "OS disk size in GB for the Linux VM"
  type        = number
  default     = 64
}

variable "linux_data_disk_size_gb" {
  description = "Data disk size in GB for the Linux VM"
  type        = number
  default     = 64
}

# ---------------------------------------------------------------------------------------------------------------------
# WINDOWS VM CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "windows_vm_size" {
  description = "VM size for the Windows access server"
  type        = string
  default     = "Standard_B2s"
}

variable "windows_admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "azureadmin"
}

variable "windows_os_disk_size_gb" {
  description = "OS disk size in GB for the Windows VM"
  type        = number
  default     = 128
  # Windows Server minimum is 127GB; keeping at 128
}
