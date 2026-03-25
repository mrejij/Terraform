output "linux_vm_id" {
  description = "ID of the Linux build server VM"
  value       = azurerm_linux_virtual_machine.build_server.id
}

output "linux_vm_name" {
  description = "Name of the Linux build server VM"
  value       = azurerm_linux_virtual_machine.build_server.name
}

output "linux_vm_private_ip" {
  description = "Private IP address of the Linux VM"
  value       = azurerm_network_interface.linux.private_ip_address
}

output "windows_vm_id" {
  description = "ID of the Windows access server VM"
  value       = azurerm_windows_virtual_machine.access_server.id
}

output "windows_vm_name" {
  description = "Name of the Windows access server VM"
  value       = azurerm_windows_virtual_machine.access_server.name
}

output "windows_vm_private_ip" {
  description = "Private IP address of the Windows VM"
  value       = azurerm_network_interface.windows.private_ip_address
}
