# ---------------------------------------------------------------------------------------------------------------------
# COMPUTE MODULE - Linux Build Server + Windows Access Server
# Depends on: networking (subnet), shared-services (Key Vault)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//compute"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
    app_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-app-subnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "shared_services" {
  config_path = "../shared-services"

  mock_outputs = {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/mock-kv"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name = dependency.networking.outputs.resource_group_name
  app_subnet_id       = dependency.networking.outputs.app_subnet_id
  key_vault_id        = dependency.shared_services.outputs.key_vault_id

  # Linux VM
  linux_vm_size           = "Standard_D2ls_v5"
  linux_os_disk_size_gb   = 64
  linux_data_disk_size_gb = 64
  linux_admin_username    = "azureadmin"

  # Windows VM
  windows_vm_size         = "Standard_D2ls_v5"
  windows_os_disk_size_gb = 128
  windows_admin_username  = "azureadmin"
}
