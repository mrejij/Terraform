# ---------------------------------------------------------------------------------------------------------------------
# USER ASSIGNED MANAGED IDENTITY
# Single identity shared across all resources for secure inter-service communication
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "main" {
  name                = "id-${var.project}-${var.environment}-${var.location_short}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ROLE ASSIGNMENTS - Resource Group Level
# ---------------------------------------------------------------------------------------------------------------------

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "rg_reader" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
