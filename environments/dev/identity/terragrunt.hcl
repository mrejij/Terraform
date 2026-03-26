# ---------------------------------------------------------------------------------------------------------------------
# IDENTITY MODULE - User Assigned Managed Identity
# Depends on: networking (resource group must exist)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//identity"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name = dependency.networking.outputs.resource_group_name
}
