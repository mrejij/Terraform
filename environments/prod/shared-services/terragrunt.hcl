# ---------------------------------------------------------------------------------------------------------------------
# SHARED SERVICES MODULE - ACR, Key Vault, Storage Account, Log Analytics
# Depends on: networking (subnet), identity (managed identity), dns (private DNS zones)
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
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "identity" {
  config_path = "../identity"

  mock_outputs = {
    managed_identity_principal_id = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs = {
    acr_private_dns_zone_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    kv_private_dns_zone_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    storage_blob_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    storage_file_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  resource_group_name           = dependency.networking.outputs.resource_group_name
  app_subnet_id                 = dependency.networking.outputs.app_subnet_id
  managed_identity_principal_id = dependency.identity.outputs.managed_identity_principal_id

  # DNS zones for private endpoints
  acr_private_dns_zone_id          = dependency.dns.outputs.acr_private_dns_zone_id
  kv_private_dns_zone_id           = dependency.dns.outputs.kv_private_dns_zone_id
  storage_blob_private_dns_zone_id = dependency.dns.outputs.storage_blob_private_dns_zone_id
  storage_file_private_dns_zone_id = dependency.dns.outputs.storage_file_private_dns_zone_id

  # Overrides (uncomment to customize)
  # log_retention_days       = 90
  # storage_replication_type = "GRS"
  # file_share_names         = ["app-data", "jenkins-data", "shared-config", "nginx-config"]
  # file_share_quota_gb      = 100
}
