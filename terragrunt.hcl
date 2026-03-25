# ---------------------------------------------------------------------------------------------------------------------
# ROOT TERRAGRUNT CONFIGURATION
# This is the root terragrunt.hcl that all child configurations inherit from.
# It configures the Azure Storage remote backend and the AzureRM provider.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Parse the env.hcl file from the nearest parent folder
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  project        = local.env_vars.locals.project
  environment    = local.env_vars.locals.environment
  location       = local.env_vars.locals.location
  location_short = local.env_vars.locals.location_short

  tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "Terraform"
    CreatedBy   = "Terragrunt"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# AZURE PROVIDER CONFIGURATION
# Generated into each module directory as provider.tf
# ---------------------------------------------------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm" {
      features {
        key_vault {
          purge_soft_delete_on_destroy    = false
          recover_soft_deleted_key_vaults = true
        }
        resource_group {
          prevent_deletion_if_contains_resources = true
        }
      }

      # Use Azure CLI authentication (az login with user credentials)
      # No Service Principal required — the provider uses the active CLI session.
      use_cli         = true
      subscription_id = "${get_env("ARM_SUBSCRIPTION_ID", "")}"
      tenant_id       = "${get_env("ARM_TENANT_ID", "")}"
    }
  EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# REMOTE STATE - AZURE STORAGE ACCOUNT
# State files are stored per-module using the relative path as the key.
# The storage account must be pre-created using scripts/setup-backend.ps1
# ---------------------------------------------------------------------------------------------------------------------
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = "rg-tfstate-${local.project}-${local.environment}"
    storage_account_name = "sttfstate${local.project}${local.environment}"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# COMMON INPUTS
# These variables are passed to every module unless overridden in the child terragrunt.hcl
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  project             = local.project
  environment         = local.environment
  location            = local.location
  location_short      = local.location_short
  tags                = local.tags
  resource_group_name = "rg-${local.project}-${local.environment}-${local.location_short}"
}
