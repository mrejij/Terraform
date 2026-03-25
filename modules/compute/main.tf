# ---------------------------------------------------------------------------------------------------------------------
# SSH KEY GENERATION FOR LINUX VM
# Private key is stored in Key Vault; never exposed in outputs
# ---------------------------------------------------------------------------------------------------------------------

resource "tls_private_key" "linux_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------------------------------------------------------------------------------------
# WINDOWS ADMIN PASSWORD (auto-generated, stored in Key Vault)
# ---------------------------------------------------------------------------------------------------------------------

resource "random_password" "windows_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%&*()-_=+[]{}|:,.?"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 4
}

# ---------------------------------------------------------------------------------------------------------------------
# LINUX VM - BUILD & DEPLOYMENT SERVER
# Jenkins, Helm, kubectl, k9s, Docker, ACR CLI will be installed on this server
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_network_interface" "linux" {
  name                = "nic-vm-linux-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.app_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "build_server" {
  name                            = "vm-linux-${var.project}-${var.environment}-${var.location_short}"
  computer_name                   = "vm-linux-${var.environment}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.linux_vm_size
  admin_username                  = var.linux_admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.linux.id]

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  admin_ssh_key {
    username   = var.linux_admin_username
    public_key = tls_private_key.linux_ssh.public_key_openssh
  }

  os_disk {
    name                 = "osdisk-vm-linux-${var.project}-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.linux_os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = var.tags
}

# Data disk for Docker images, builds, and workspace
resource "azurerm_managed_disk" "linux_data" {
  name                 = "datadisk-vm-linux-${var.project}-${var.environment}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.linux_data_disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "linux_data" {
  managed_disk_id    = azurerm_managed_disk.linux_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.build_server.id
  lun                = 0
  caching            = "ReadWrite"
}

# ---------------------------------------------------------------------------------------------------------------------
# WINDOWS VM - ACCESS SERVER
# For accessing application UI, Jenkins dashboard, and other web UIs via browser
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_network_interface" "windows" {
  name                = "nic-vm-win-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.app_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "access_server" {
  name                = "vm-win-${var.project}-${var.environment}-${var.location_short}"
  computer_name       = "VMWIN${upper(var.environment)}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.windows_vm_size
  admin_username      = var.windows_admin_username
  admin_password      = random_password.windows_admin.result

  network_interface_ids = [azurerm_network_interface.windows.id]

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  os_disk {
    name                 = "osdisk-vm-win-${var.project}-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.windows_os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# KEY VAULT SECRETS - Store all credentials securely
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_key_vault_secret" "linux_ssh_private_key" {
  name         = "linux-ssh-private-key"
  value        = tls_private_key.linux_ssh.private_key_pem
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "linux_ssh_public_key" {
  name         = "linux-ssh-public-key"
  value        = tls_private_key.linux_ssh.public_key_openssh
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "linux_admin_username" {
  name         = "linux-admin-username"
  value        = var.linux_admin_username
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "windows_admin_username" {
  name         = "windows-admin-username"
  value        = var.windows_admin_username
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "windows_admin_password" {
  name         = "windows-admin-password"
  value        = random_password.windows_admin.result
  key_vault_id = var.key_vault_id
}
