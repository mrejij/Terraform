# ---------------------------------------------------------------------------------------------------------------------
# AKS MODULE - Private AKS Cluster with System + Worker Node Pools
# Depends on: networking, identity, dns, shared-services
# This should be deployed last after all dependencies are in place.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//aks"
}

dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_name = "mock-rg"
    aks_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/mock-aks-subnet"
    vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "identity" {
  config_path = "../identity"

  mock_outputs = {
    managed_identity_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock-id"
    managed_identity_principal_id = "00000000-0000-0000-0000-000000000000"
    managed_identity_client_id    = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs = {
    aks_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.eastus.azmk8s.io"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "shared_services" {
  config_path = "../shared-services"

  mock_outputs = {
    acr_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ContainerRegistry/registries/mock-acr"
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.OperationalInsights/workspaces/mock-law"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  resource_group_name       = dependency.networking.outputs.resource_group_name
  aks_subnet_id             = dependency.networking.outputs.aks_subnet_id
  vnet_id                   = dependency.networking.outputs.vnet_id
  managed_identity_id       = dependency.identity.outputs.managed_identity_id
  managed_identity_principal_id = dependency.identity.outputs.managed_identity_principal_id
  managed_identity_client_id    = dependency.identity.outputs.managed_identity_client_id
  aks_private_dns_zone_id   = dependency.dns.outputs.aks_private_dns_zone_id
  acr_id                    = dependency.shared_services.outputs.acr_id
  log_analytics_workspace_id = dependency.shared_services.outputs.log_analytics_workspace_id

  # AKS cluster configuration (cost-optimized for free trial)
  kubernetes_version  = "1.29"
  system_node_count   = 1
  system_node_vm_size = "Standard_B2s"
  worker_node_count   = 1
  worker_node_vm_size = "Standard_B2ms"
  service_cidr        = "172.16.0.0/16"
  dns_service_ip      = "172.16.0.10"
  max_pods_per_node   = 30
}
