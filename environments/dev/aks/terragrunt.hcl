# ---------------------------------------------------------------------------------------------------------------------
# AKS MODULE - Private AKS Cluster with System + Worker Node Pools
# Depends on: networking, dns, shared-services (AKS SP creds + ACR + LAW)
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
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "dns" {
  config_path = "../dns"

  mock_outputs = {
    aks_private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/privateDnsZones/privatelink.centralindia.azmk8s.io"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "shared_services" {
  config_path = "../shared-services"

  mock_outputs = {
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.OperationalInsights/workspaces/mock-law"
    aks_sp_client_id           = "00000000-0000-0000-0000-000000000000"
    aks_sp_client_secret       = "mock-secret"
    aks_sp_object_id           = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  resource_group_name        = dependency.networking.outputs.resource_group_name
  aks_subnet_id              = dependency.networking.outputs.aks_subnet_id
  vnet_id                    = dependency.networking.outputs.vnet_id
  aks_private_dns_zone_id    = dependency.dns.outputs.aks_private_dns_zone_id
  log_analytics_workspace_id = dependency.shared_services.outputs.log_analytics_workspace_id

  # AKS Service Principal (from bootstrap Key Vault via shared-services)
  aks_sp_client_id     = dependency.shared_services.outputs.aks_sp_client_id
  aks_sp_client_secret = dependency.shared_services.outputs.aks_sp_client_secret
  aks_sp_object_id     = dependency.shared_services.outputs.aks_sp_object_id

  # AKS cluster configuration
  kubernetes_version    = "1.31.0"
  system_node_count     = 1
  system_node_vm_size   = "Standard_D2ls_v5"
  worker_node_min_count = 2
  worker_node_max_count = 4
  worker_node_vm_size   = "Standard_D4s_v3"
  aks_sku_tier          = "Standard"
  service_cidr          = "172.16.0.0/16"
  dns_service_ip        = "172.16.0.10"
  max_pods_per_node     = 30
}
