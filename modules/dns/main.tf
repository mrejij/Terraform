# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE DNS ZONES FOR AZURE SERVICES (PRIVATE ENDPOINTS)
# Each Azure service with a private endpoint requires a corresponding private DNS zone
# for automatic DNS resolution of the private endpoint IP.
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "services" {
  for_each            = toset(var.private_dns_zone_names)
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "services" {
  for_each              = azurerm_private_dns_zone.services
  name                  = "vnetlink-${replace(each.key, ".", "-")}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# AKS PRIVATE DNS ZONE
# Private AKS cluster uses this zone for API server DNS resolution.
# Zone name format: privatelink.<region>.azmk8s.io
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "vnetlink-aks-private"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# INTERNAL DNS ZONE FOR NGINX INGRESS SERVICES
# Wildcard A record will be added post-deployment once the NGINX ingress LB IP is known.
# Map: *.svc.cluster.internal -> NGINX Ingress Internal LB IP
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "internal" {
  name                = var.internal_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "vnetlink-internal-services"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}
