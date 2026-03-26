output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL of the ACR"
  value       = azurerm_container_registry.main.login_server
}

output "key_vault_id" {
  description = "ID of the Azure Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_access_key" {
  description = "Primary access key of the Storage Account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "random_suffix" {
  description = "Random suffix used for globally unique resource names"
  value       = random_string.suffix.result
}

# AKS Service Principal outputs (sourced from bootstrap Key Vault)
output "aks_sp_client_id" {
  description = "AKS Service Principal Client ID"
  value       = data.azurerm_key_vault_secret.aks_sp_client_id.value
  sensitive   = true
}

output "aks_sp_client_secret" {
  description = "AKS Service Principal Client Secret"
  value       = data.azurerm_key_vault_secret.aks_sp_client_secret.value
  sensitive   = true
}

output "aks_sp_object_id" {
  description = "AKS Service Principal Object ID"
  value       = data.azurerm_key_vault_secret.aks_sp_object_id.value
  sensitive   = true
}
