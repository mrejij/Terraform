# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING MODULE - VNet, Subnets, NSGs
# This is the first module to deploy; creates the resource group and all networking.
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/modules//networking"
}

inputs = {
  vnet_address_space             = "10.0.0.0/16"
  aks_subnet_address_prefix      = "10.0.1.0/24"
  database_subnet_address_prefix = "10.0.2.0/24"
  app_subnet_address_prefix      = "10.0.3.0/24"
  bastion_subnet_address_prefix  = "10.0.4.0/26"
  deployer_ip                    = "163.116.213.95/32"
}
