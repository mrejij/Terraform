#!/usr/bin/env bash
# =====================================================================================================================
# BOOTSTRAP SCRIPT - Creates Service Principals, Bootstrap Key Vault, and stores credentials
# Pre-requisite: Run BEFORE any Terraform/Terragrunt operations
#
# Creates:
#   1. Bootstrap Resource Group
#   2. Bootstrap Key Vault
#   3. Terraform Service Principal (for Terraform/Terragrunt auth)
#   4. AKS Service Principal (for AKS cluster identity + ACR access)
#   5. Stores all SP credentials in the Bootstrap Key Vault
#   6. Assigns required RBAC roles
#
# Usage: bash setup-bootstrap.sh
# =====================================================================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — Update these values for your environment
# ─────────────────────────────────────────────────────────────────────────────
PROJECT="3tierapp"
ENVIRONMENT="dev"
LOCATION="centralindia"
LOCATION_SHORT="cav"

# Subscription and Tenant
SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:?Set ARM_SUBSCRIPTION_ID}"
TENANT_ID="${ARM_TENANT_ID:?Set ARM_TENANT_ID}"

# Bootstrap resource names
BOOTSTRAP_RG="rg-bootstrap-${PROJECT}-${ENVIRONMENT}"
BOOTSTRAP_KV="kv-boot-${PROJECT}-${ENVIRONMENT}"

# Service principal display names
TF_SP_NAME="sp-terraform-${PROJECT}-${ENVIRONMENT}"
AKS_SP_NAME="sp-aks-${PROJECT}-${ENVIRONMENT}"

echo "==========================================="
echo "  Bootstrap Setup"
echo "==========================================="
echo "  Project:      ${PROJECT}"
echo "  Environment:  ${ENVIRONMENT}"
echo "  Location:     ${LOCATION}"
echo "  Subscription: ${SUBSCRIPTION_ID}"
echo "==========================================="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PRE-CHECKS
# ─────────────────────────────────────────────────────────────────────────────
echo "[0/7] Verifying Azure CLI login..."
az account show --query "id" -o tsv > /dev/null 2>&1 || {
    echo "  ERROR: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
}
az account set --subscription "${SUBSCRIPTION_ID}"
echo "  Using subscription: $(az account show --query name -o tsv)"

# ─────────────────────────────────────────────────────────────────────────────
# 1. CREATE BOOTSTRAP RESOURCE GROUP
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[1/7] Creating bootstrap resource group: ${BOOTSTRAP_RG}..."
az group create \
    --name "${BOOTSTRAP_RG}" \
    --location "${LOCATION}" \
    --tags Project="${PROJECT}" Environment="${ENVIRONMENT}" Purpose="Bootstrap" ManagedBy="Script" \
    --output none
echo "  Resource group created."

# ─────────────────────────────────────────────────────────────────────────────
# 2. CREATE BOOTSTRAP KEY VAULT
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[2/7] Creating bootstrap Key Vault: ${BOOTSTRAP_KV}..."
az keyvault create \
    --name "${BOOTSTRAP_KV}" \
    --resource-group "${BOOTSTRAP_RG}" \
    --location "${LOCATION}" \
    --enable-rbac-authorization true \
    --sku standard \
    --output none
echo "  Key Vault created."

# Grant current user Key Vault Secrets Officer on bootstrap KV
CURRENT_USER_OID=$(az ad signed-in-user show --query id -o tsv)
BOOTSTRAP_KV_ID=$(az keyvault show --name "${BOOTSTRAP_KV}" --resource-group "${BOOTSTRAP_RG}" --query id -o tsv)

echo "  Granting Key Vault Secrets Officer to current user..."
az role assignment create \
    --role "Key Vault Secrets Officer" \
    --assignee-object-id "${CURRENT_USER_OID}" \
    --assignee-principal-type "User" \
    --scope "${BOOTSTRAP_KV_ID}" \
    --output none 2>/dev/null || echo "  (Role assignment may already exist — OK)"

# Wait for RBAC propagation
echo "  Waiting for RBAC propagation (30s)..."
sleep 30

# ─────────────────────────────────────────────────────────────────────────────
# 3. CREATE TERRAFORM SERVICE PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[3/7] Creating Terraform Service Principal: ${TF_SP_NAME}..."

# Check if SP already exists
TF_APP_ID=$(az ad app list --display-name "${TF_SP_NAME}" --query "[0].appId" -o tsv 2>/dev/null || true)

if [ -z "${TF_APP_ID}" ] || [ "${TF_APP_ID}" = "None" ]; then
    # Create new app registration + SP
    TF_SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "${TF_SP_NAME}" \
        --role "Contributor" \
        --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
        --query "{clientId: appId, clientSecret: password, tenantId: tenant}" \
        -o json)

    TF_SP_CLIENT_ID=$(echo "${TF_SP_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientId'])")
    TF_SP_CLIENT_SECRET=$(echo "${TF_SP_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")

    echo "  Terraform SP created: ${TF_SP_CLIENT_ID}"
else
    TF_SP_CLIENT_ID="${TF_APP_ID}"
    echo "  Terraform SP already exists: ${TF_SP_CLIENT_ID}"
    echo "  Resetting credentials..."
    TF_SP_CRED=$(az ad app credential reset --id "${TF_SP_CLIENT_ID}" --query "{clientSecret: password}" -o json)
    TF_SP_CLIENT_SECRET=$(echo "${TF_SP_CRED}" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")
fi

# Get Terraform SP Object ID
TF_SP_OBJECT_ID=$(az ad sp show --id "${TF_SP_CLIENT_ID}" --query id -o tsv)

# Assign User Access Administrator (to manage RBAC for resources Terraform creates)
echo "  Assigning User Access Administrator role..."
az role assignment create \
    --role "User Access Administrator" \
    --assignee-object-id "${TF_SP_OBJECT_ID}" \
    --assignee-principal-type "ServicePrincipal" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}" \
    --output none 2>/dev/null || echo "  (Role may already exist — OK)"

# Grant Terraform SP read access to bootstrap Key Vault secrets
echo "  Granting Key Vault Secrets User to Terraform SP on bootstrap KV..."
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "${TF_SP_OBJECT_ID}" \
    --assignee-principal-type "ServicePrincipal" \
    --scope "${BOOTSTRAP_KV_ID}" \
    --output none 2>/dev/null || echo "  (Role may already exist — OK)"

# ─────────────────────────────────────────────────────────────────────────────
# 4. CREATE AKS SERVICE PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[4/7] Creating AKS Service Principal: ${AKS_SP_NAME}..."

AKS_APP_ID=$(az ad app list --display-name "${AKS_SP_NAME}" --query "[0].appId" -o tsv 2>/dev/null || true)

if [ -z "${AKS_APP_ID}" ] || [ "${AKS_APP_ID}" = "None" ]; then
    AKS_SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "${AKS_SP_NAME}" \
        --skip-assignment \
        --query "{clientId: appId, clientSecret: password, tenantId: tenant}" \
        -o json)

    AKS_SP_CLIENT_ID=$(echo "${AKS_SP_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientId'])")
    AKS_SP_CLIENT_SECRET=$(echo "${AKS_SP_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")

    echo "  AKS SP created: ${AKS_SP_CLIENT_ID}"
else
    AKS_SP_CLIENT_ID="${AKS_APP_ID}"
    echo "  AKS SP already exists: ${AKS_SP_CLIENT_ID}"
    echo "  Resetting credentials..."
    AKS_SP_CRED=$(az ad app credential reset --id "${AKS_SP_CLIENT_ID}" --query "{clientSecret: password}" -o json)
    AKS_SP_CLIENT_SECRET=$(echo "${AKS_SP_CRED}" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientSecret'])")
fi

# Get AKS SP Object ID
AKS_SP_OBJECT_ID=$(az ad sp show --id "${AKS_SP_CLIENT_ID}" --query id -o tsv)

echo "  AKS SP Object ID: ${AKS_SP_OBJECT_ID}"

# ─────────────────────────────────────────────────────────────────────────────
# 5. STORE SECRETS IN BOOTSTRAP KEY VAULT
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[5/7] Storing credentials in bootstrap Key Vault..."

az keyvault secret set --vault-name "${BOOTSTRAP_KV}" --name "tf-sp-client-id"      --value "${TF_SP_CLIENT_ID}"      --output none
az keyvault secret set --vault-name "${BOOTSTRAP_KV}" --name "tf-sp-client-secret"   --value "${TF_SP_CLIENT_SECRET}"  --output none
az keyvault secret set --vault-name "${BOOTSTRAP_KV}" --name "tf-sp-object-id"       --value "${TF_SP_OBJECT_ID}"      --output none
az keyvault secret set --vault-name "${BOOTSTRAP_KV}" --name "aks-sp-client-id"      --value "${AKS_SP_CLIENT_ID}"     --output none
az keyvault secret set --vault-name "${BOOTSTRAP_KV}" --name "aks-sp-client-secret"  --value "${AKS_SP_CLIENT_SECRET}" --output none
az keyvault secret set --vault-name "${BOOTSTRAP_KV}" --name "aks-sp-object-id"      --value "${AKS_SP_OBJECT_ID}"     --output none

echo "  All secrets stored."

# ─────────────────────────────────────────────────────────────────────────────
# 6. ASSIGN AKS SP ROLES (minimal pre-deployment roles)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[6/7] Assigning base roles to AKS SP..."

# AKS SP needs Network Contributor at subscription or RG level (Terraform will also assign at VNet/DNS scope)
az role assignment create \
    --role "Network Contributor" \
    --assignee-object-id "${AKS_SP_OBJECT_ID}" \
    --assignee-principal-type "ServicePrincipal" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}" \
    --output none 2>/dev/null || echo "  (Role may already exist — OK)"

echo "  AKS SP base roles assigned."

# ─────────────────────────────────────────────────────────────────────────────
# 7. SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
echo "  Bootstrap Complete!"
echo "==========================================="
echo ""
echo "Bootstrap Resources:"
echo "  Resource Group:  ${BOOTSTRAP_RG}"
echo "  Key Vault:       ${BOOTSTRAP_KV}"
echo ""
echo "Terraform Service Principal:"
echo "  Display Name:    ${TF_SP_NAME}"
echo "  Client ID:       ${TF_SP_CLIENT_ID}"
echo "  Object ID:       ${TF_SP_OBJECT_ID}"
echo ""
echo "AKS Service Principal:"
echo "  Display Name:    ${AKS_SP_NAME}"
echo "  Client ID:       ${AKS_SP_CLIENT_ID}"
echo "  Object ID:       ${AKS_SP_OBJECT_ID}"
echo ""
echo "Set these environment variables before running Terragrunt:"
echo ""
echo "  export ARM_SUBSCRIPTION_ID=\"${SUBSCRIPTION_ID}\""
echo "  export ARM_TENANT_ID=\"${TENANT_ID}\""
echo "  export ARM_CLIENT_ID=\"${TF_SP_CLIENT_ID}\""
echo "  export ARM_CLIENT_SECRET=\"${TF_SP_CLIENT_SECRET}\""
echo "  export BOOTSTRAP_KEY_VAULT_NAME=\"${BOOTSTRAP_KV}\""
echo "  export BOOTSTRAP_RESOURCE_GROUP=\"${BOOTSTRAP_RG}\""
echo ""
echo "For GitHub Actions, add these as repository secrets:"
echo "  ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET"
echo "  BOOTSTRAP_KEY_VAULT_NAME, BOOTSTRAP_RESOURCE_GROUP"
echo ""
echo "Next steps:"
echo "  1. Export the env vars shown above"
echo "  2. Run setup-backend.sh (if not done already)"
echo "  3. cd environments/dev && terragrunt run --all -- init"
echo "  4. terragrunt run --all -- plan"
echo "  5. terragrunt run --all -- apply"
