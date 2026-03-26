#!/usr/bin/env bash
# =====================================================================================================================
# SETUP AZURE STORAGE BACKEND FOR TERRAFORM STATE
# Run this script ONCE before the first terragrunt run-all apply.
# It creates the storage account and container used by Terragrunt remote_state.
# =====================================================================================================================

set -euo pipefail

PROJECT="${1:-threetier}"
ENVIRONMENT="${2:-prod}"
LOCATION="${3:-eastus}"

RG_NAME="rg-tfstate-${PROJECT}-${ENVIRONMENT}"
SA_NAME="sttfstate${PROJECT}${ENVIRONMENT}"
CONTAINER="tfstate"

echo "=== Terraform State Backend Setup ==="
echo "Resource Group : ${RG_NAME}"
echo "Storage Account: ${SA_NAME}"
echo "Container      : ${CONTAINER}"
echo "Location       : ${LOCATION}"
echo ""

# Create resource group
echo "Creating resource group..."
az group create --name "${RG_NAME}" --location "${LOCATION}" --output none

# Create storage account with security best practices
echo "Creating storage account..."
az storage account create \
    --name "${SA_NAME}" \
    --resource-group "${RG_NAME}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --https-only true \
    --output none

# Enable versioning for state file recovery
echo "Enabling blob versioning..."
az storage account blob-service-properties update \
    --account-name "${SA_NAME}" \
    --resource-group "${RG_NAME}" \
    --enable-versioning true \
    --output none

# Create container
echo "Creating blob container..."
az storage container create \
    --name "${CONTAINER}" \
    --account-name "${SA_NAME}" \
    --auth-mode login \
    --output none

# Enable delete lock on the resource group to prevent accidental deletion
echo "Adding delete lock..."
az lock create \
    --name "tfstate-lock" \
    --resource-group "${RG_NAME}" \
    --lock-type CanNotDelete \
    --notes "Protects Terraform state storage from accidental deletion" \
    --output none

echo ""
echo "=== Backend setup complete ==="
echo "You can now run: cd environments/prod && terragrunt run-all init"
