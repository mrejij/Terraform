# ---------------------------------------------------------------------------------------------------------------------
# DATABASE MODULE - Azure SQL Server & Database
# Depends on: networking (subnet), dns (SQL DNS zone), shared-services (KV, LAW)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//database"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
    database_subnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-db-subnet"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs = {
    sql_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "shared_services" {
  config_path = "../shared-services"

  mock_outputs = {
    key_vault_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.KeyVault/vaults/mock-kv"
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.OperationalInsights/workspaces/mock-law"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name        = dependency.networking.outputs.resource_group_name
  database_subnet_id         = dependency.networking.outputs.database_subnet_id
  sql_private_dns_zone_id    = dependency.dns.outputs.sql_private_dns_zone_id
  key_vault_id               = dependency.shared_services.outputs.key_vault_id
  log_analytics_workspace_id = dependency.shared_services.outputs.log_analytics_workspace_id

  # SQL configuration
  sql_admin_username        = "sqladmin"
  sql_database_sku          = "S0"
  sql_database_max_size_gb  = 10
  sql_zone_redundant        = false
  sql_backup_retention_days = 7
  aad_admin_login           = "sqlaadadmin"
}
