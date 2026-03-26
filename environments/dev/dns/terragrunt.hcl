# ---------------------------------------------------------------------------------------------------------------------
# DNS MODULE - Private DNS Zones and VNet Links
# Depends on: networking (VNet ID)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//dns"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name = dependency.networking.outputs.resource_group_name
  virtual_network_id  = dependency.networking.outputs.vnet_id

  private_dns_zone_names = [
    "privatelink.azurecr.io",
    "privatelink.vaultcore.azure.net",
    "privatelink.database.windows.net",
    "privatelink.blob.core.windows.net",
    "privatelink.file.core.windows.net"
  ]

  internal_dns_zone_name = "svc.cluster.internal"
}
