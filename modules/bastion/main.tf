# ---------------------------------------------------------------------------------------------------------------------
# BASTION PUBLIC IP
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE BASTION HOST
# Standard SKU enables tunneling, file copy, shareable links
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_bastion_host" "main" {
  name                   = "bas-${var.project}-${var.environment}-${var.location_short}"
  location               = var.location
  resource_group_name    = var.resource_group_name
  sku                    = "Basic"
  copy_paste_enabled     = true

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "bastion" {
  count                      = var.log_analytics_workspace_id != "" ? 1 : 0
  name                       = "diag-bastion-${var.project}-${var.environment}"
  target_resource_id         = azurerm_bastion_host.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "BastionAuditLogs"
  }

  metric {
    category = "AllMetrics"
  }
}
