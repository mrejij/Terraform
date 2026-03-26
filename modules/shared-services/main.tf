data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# BOOTSTRAP KEY VAULT - Read AKS Service Principal credentials
# The bootstrap KV is pre-created by scripts/setup-bootstrap.sh
# ---------------------------------------------------------------------------------------------------------------------

data "azurerm_key_vault" "bootstrap" {
  name                = var.bootstrap_key_vault_name
  resource_group_name = var.bootstrap_resource_group
}

data "azurerm_key_vault_secret" "aks_sp_client_id" {
  name         = "aks-sp-client-id"
  key_vault_id = data.azurerm_key_vault.bootstrap.id
}

data "azurerm_key_vault_secret" "aks_sp_client_secret" {
  name         = "aks-sp-client-secret"
  key_vault_id = data.azurerm_key_vault.bootstrap.id
}

data "azurerm_key_vault_secret" "aks_sp_object_id" {
  name         = "aks-sp-object-id"
  key_vault_id = data.azurerm_key_vault.bootstrap.id
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

locals {
  suffix = random_string.suffix.result
}

# ---------------------------------------------------------------------------------------------------------------------
# LOG ANALYTICS WORKSPACE
# Central monitoring workspace for all resources
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE CONTAINER REGISTRY (Premium SKU required for private endpoints)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_container_registry" "main" {
  name                          = "acr${var.project}${var.environment}${local.suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  network_rule_bypass_option    = "AzureServices"
  zone_redundancy_enabled       = false
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.app_subnet_id

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [var.acr_private_dns_zone_id]
  }

  tags = var.tags
}

# ACRPull + ACRPush roles for the AKS Service Principal
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_key_vault_secret.aks_sp_object_id.value
}

resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_key_vault_secret.aks_sp_object_id.value
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE KEY VAULT (RBAC authorization model)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project}-${var.environment}-${local.suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = var.kv_public_network_access_enabled
  rbac_authorization_enabled    = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.deployer_ip_ranges
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.app_subnet_id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [var.kv_private_dns_zone_id]
  }

  tags = var.tags
}

# Key Vault Secrets User for the AKS SP (CSI secrets store driver)
resource "azurerm_role_assignment" "kv_secrets_user_aks_sp" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_key_vault_secret.aks_sp_object_id.value
}

# Key Vault Secrets Officer for the Terraform deployer SP (to create secrets)
resource "azurerm_role_assignment" "kv_secrets_officer_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------------------------------------------------------------
# STORAGE ACCOUNT (File shares for pod data persistence)
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_storage_account" "main" {
  name                            = "st${var.project}${var.environment}${local.suffix}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

resource "azurerm_storage_share" "shares" {
  for_each           = toset(var.file_share_names)
  name               = each.value
  storage_account_id = azurerm_storage_account.main.id
  quota              = var.file_share_quota_gb
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-stblob-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.app_subnet_id

  private_service_connection {
    name                           = "psc-stblob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "stblob-dns-zone-group"
    private_dns_zone_ids = [var.storage_blob_private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "storage_file" {
  name                = "pe-stfile-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.app_subnet_id

  private_service_connection {
    name                           = "psc-stfile"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "stfile-dns-zone-group"
    private_dns_zone_ids = [var.storage_file_private_dns_zone_id]
  }

  tags = var.tags
}

# Storage Blob Data Contributor for the AKS SP
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_key_vault_secret.aks_sp_object_id.value
}

# Storage File Data SMB Share Contributor for AKS SP (pod mounts)
resource "azurerm_role_assignment" "storage_file_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azurerm_key_vault_secret.aks_sp_object_id.value
}

# Diagnostic settings for Key Vault
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv-${var.project}-${var.environment}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}
