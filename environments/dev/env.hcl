# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT-LEVEL VARIABLES FOR PRODUCTION
# These values are read by the root terragrunt.hcl and injected into all modules.
# To add a new environment, copy this folder and update the values below.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  project        = "3tierapp"
  environment    = "dev"
  location       = "centralindia"
  location_short = "cav"
}
