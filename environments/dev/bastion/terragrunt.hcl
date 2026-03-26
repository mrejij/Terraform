# ---------------------------------------------------------------------------------------------------------------------
# BASTION MODULE - Azure Bastion for secure VM access
# Depends on: networking (bastion subnet), shared-services (log analytics - optional)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//bastion"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
    bastion_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/AzureBastionSubnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "shared_services" {
  config_path = "../shared-services"

  mock_outputs = {
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.OperationalInsights/workspaces/mock-law"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name        = dependency.networking.outputs.resource_group_name
  bastion_subnet_id          = dependency.networking.outputs.bastion_subnet_id
  log_analytics_workspace_id = dependency.shared_services.outputs.log_analytics_workspace_id
}
