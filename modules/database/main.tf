# ---------------------------------------------------------------------------------------------------------------------
# SQL ADMIN PASSWORD (auto-generated, stored in Key Vault)
# ---------------------------------------------------------------------------------------------------------------------

resource "random_password" "sql_admin" {
  length           = 32
  special          = true
  override_special = "!@#$%&*()-_=+[]{}|:,.?"
  min_lower        = 4
  min_upper        = 4
  min_numeric      = 4
  min_special      = 4
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE SQL SERVER
# Public access disabled; accessible only via private endpoint on database subnet.
# Both SQL auth and Azure AD auth are enabled.
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_mssql_server" "main" {
  name                          = "sql-${var.project}-${var.environment}-${var.location_short}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = random_password.sql_admin.result
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username = var.aad_admin_login
    object_id      = var.managed_identity_principal_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  primary_user_assigned_identity_id = var.managed_identity_id

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# SQL DATABASE
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_mssql_database" "main" {
  name                        = "sqldb-${var.project}-${var.environment}"
  server_id                   = azurerm_mssql_server.main.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                 = var.sql_database_max_size_gb
  sku_name                    = var.sql_database_sku
  zone_redundant              = var.sql_zone_redundant
  geo_backup_enabled          = false
  ledger_enabled              = false

  short_term_retention_policy {
    retention_days = var.sql_backup_retention_days
  }

  tags = var.tags
}

# Auditing policy
resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id                               = azurerm_mssql_server.main.id
  log_monitoring_enabled                  = true
  storage_endpoint                        = null
}

# ---------------------------------------------------------------------------------------------------------------------
# PRIVATE ENDPOINT - Database Subnet
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.project}-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.database_subnet_id

  private_service_connection {
    name                           = "psc-sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [var.sql_private_dns_zone_id]
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "sql_db" {
  name                       = "diag-sqldb-${var.project}-${var.environment}"
  target_resource_id         = azurerm_mssql_database.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_log {
    category = "SQLInsights"
  }

  metric {
    category = "Basic"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# KEY VAULT SECRETS - SQL Credentials
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_key_vault_secret" "sql_admin_username" {
  name         = "sql-admin-username"
  value        = var.sql_admin_username
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.main.name};Persist Security Info=False;User ID=${var.sql_admin_username};Password=${random_password.sql_admin.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "sql_server_fqdn" {
  name         = "sql-server-fqdn"
  value        = azurerm_mssql_server.main.fully_qualified_domain_name
  key_vault_id = var.key_vault_id
}
