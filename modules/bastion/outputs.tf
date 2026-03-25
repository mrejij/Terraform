output "bastion_id" {
  description = "ID of the Bastion host"
  value       = azurerm_bastion_host.main.id
}

output "bastion_name" {
  description = "Name of the Bastion host"
  value       = azurerm_bastion_host.main.name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host"
  value       = azurerm_public_ip.bastion.ip_address
}
