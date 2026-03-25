# Map of DNS zone name -> zone ID for all service zones
output "private_dns_zone_ids" {
  description = "Map of private DNS zone names to their IDs"
  value       = { for k, v in azurerm_private_dns_zone.services : k => v.id }
}

# Individual zone IDs for ease of use in dependent modules
output "acr_private_dns_zone_id" {
  description = "ID of the ACR private DNS zone"
  value       = azurerm_private_dns_zone.services["privatelink.azurecr.io"].id
}

output "kv_private_dns_zone_id" {
  description = "ID of the Key Vault private DNS zone"
  value       = azurerm_private_dns_zone.services["privatelink.vaultcore.azure.net"].id
}

output "sql_private_dns_zone_id" {
  description = "ID of the SQL private DNS zone"
  value       = azurerm_private_dns_zone.services["privatelink.database.windows.net"].id
}

output "storage_blob_private_dns_zone_id" {
  description = "ID of the Storage Blob private DNS zone"
  value       = azurerm_private_dns_zone.services["privatelink.blob.core.windows.net"].id
}

output "storage_file_private_dns_zone_id" {
  description = "ID of the Storage File private DNS zone"
  value       = azurerm_private_dns_zone.services["privatelink.file.core.windows.net"].id
}

output "aks_private_dns_zone_id" {
  description = "ID of the AKS private DNS zone"
  value       = azurerm_private_dns_zone.aks.id
}

output "internal_dns_zone_id" {
  description = "ID of the internal service DNS zone"
  value       = azurerm_private_dns_zone.internal.id
}

output "internal_dns_zone_name" {
  description = "Name of the internal DNS zone"
  value       = azurerm_private_dns_zone.internal.name
}
