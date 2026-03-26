# ---------------------------------------------------------------------------------------------------------------------
# SHARED SERVICES MODULE - ACR, Key Vault, Storage Account, Log Analytics
# Depends on: networking (subnet), dns (private DNS zones)
# Reads AKS SP credentials from bootstrap Key Vault
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//shared-services"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
    app_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-app-subnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs = {
    acr_private_dns_zone_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    kv_private_dns_zone_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    storage_blob_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    storage_file_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name = dependency.networking.outputs.resource_group_name
  app_subnet_id       = dependency.networking.outputs.app_subnet_id

  # DNS zones for private endpoints
  acr_private_dns_zone_id          = dependency.dns.outputs.acr_private_dns_zone_id
  kv_private_dns_zone_id           = dependency.dns.outputs.kv_private_dns_zone_id
  storage_blob_private_dns_zone_id = dependency.dns.outputs.storage_blob_private_dns_zone_id
  storage_file_private_dns_zone_id = dependency.dns.outputs.storage_file_private_dns_zone_id

  # Key Vault config — public access with deployer IP for dev (use PE-only in prod)
  kv_public_network_access_enabled = true
  deployer_ip_ranges               = ["163.116.213.95/32"]
}
