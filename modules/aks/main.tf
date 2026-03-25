# ---------------------------------------------------------------------------------------------------------------------
# ROLE ASSIGNMENTS (must be created before AKS cluster)
# The managed identity needs these permissions to manage the private AKS cluster.
# ---------------------------------------------------------------------------------------------------------------------

# Private DNS Zone Contributor - for AKS to register API server in private DNS
resource "azurerm_role_assignment" "dns_zone_contributor" {
  scope                = var.aks_private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = var.managed_identity_principal_id
}

# Network Contributor on VNet - for AKS to create internal load balancers and manage routes
resource "azurerm_role_assignment" "vnet_network_contributor" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = var.managed_identity_principal_id
}

# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE AKS CLUSTER
# - Private cluster: API server accessible only within the VNet
# - Azure CNI: Pods get IPs from the AKS subnet
# - Calico network policy: For granular pod-to-pod traffic control
# - CSI Secrets Store: Integrates with Azure Key Vault
# - Azure RBAC: For Kubernetes RBAC via Azure AD
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "main" {
  name                      = "aks-${var.project}-${var.environment}-${var.location_short}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix_private_cluster = "aks-${var.project}-${var.environment}"
  kubernetes_version        = var.kubernetes_version
  private_cluster_enabled   = true
  private_dns_zone_id       = var.aks_private_dns_zone_id
  sku_tier                  = "Free"
  local_account_disabled    = false

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_vm_size
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = 64
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    max_pods            = var.max_pods_per_node

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    managed            = true
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.dns_zone_contributor,
    azurerm_role_assignment.vnet_network_contributor
  ]

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# WORKER NODE POOL
# Dedicated pool for application workloads (frontend + backend microservices)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "worker" {
  name                  = "worker"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.worker_node_vm_size
  node_count            = var.worker_node_count
  vnet_subnet_id        = var.aks_subnet_id
  os_disk_size_gb       = 64
  os_disk_type          = "Managed"
  max_pods              = var.max_pods_per_node

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ACR PULL ROLE FOR KUBELET IDENTITY
# AKS auto-creates a kubelet identity; we grant it ACRPull so pods can pull images.
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

# ---------------------------------------------------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks-${var.project}-${var.environment}"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }

  metric {
    category = "AllMetrics"
  }
}
