# =====================================================================================================================
# SETUP AZURE STORAGE BACKEND FOR TERRAFORM STATE
# Run this script ONCE before the first terragrunt run-all apply.
# It creates the storage account and container used by Terragrunt remote_state.
# =====================================================================================================================

param(
    [string]$Project       = "threetier",
    [string]$Environment   = "prod",
    [string]$Location      = "eastus"
)

$ErrorActionPreference = "Stop"

$rgName   = "rg-tfstate-${Project}-${Environment}"
$saName   = "sttfstate${Project}${Environment}"
$container = "tfstate"

Write-Host "=== Terraform State Backend Setup ===" -ForegroundColor Cyan
Write-Host "Resource Group : $rgName"
Write-Host "Storage Account: $saName"
Write-Host "Container      : $container"
Write-Host "Location       : $Location"
Write-Host ""

# Create resource group
Write-Host "Creating resource group..." -ForegroundColor Yellow
az group create --name $rgName --location $Location --output none

# Create storage account with security best practices
Write-Host "Creating storage account..." -ForegroundColor Yellow
az storage account create `
    --name $saName `
    --resource-group $rgName `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --https-only true `
    --output none

# Enable versioning for state file recovery
Write-Host "Enabling blob versioning..." -ForegroundColor Yellow
az storage account blob-service-properties update `
    --account-name $saName `
    --resource-group $rgName `
    --enable-versioning true `
    --output none

# Create container
Write-Host "Creating blob container..." -ForegroundColor Yellow
az storage container create `
    --name $container `
    --account-name $saName `
    --auth-mode login `
    --output none

# Enable delete lock on the resource group to prevent accidental deletion
Write-Host "Adding delete lock..." -ForegroundColor Yellow
az lock create `
    --name "tfstate-lock" `
    --resource-group $rgName `
    --lock-type CanNotDelete `
    --notes "Protects Terraform state storage from accidental deletion" `
    --output none

Write-Host ""
Write-Host "=== Backend setup complete ===" -ForegroundColor Green
Write-Host "You can now run: cd environments/prod && terragrunt run-all init"
