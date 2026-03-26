# 3-Tier Production-Grade Azure Infrastructure

Production-ready Infrastructure as Code for a 3-tier application (Angular frontend, ASP.NET backend, SQL Server database) running on Azure Kubernetes Service. Uses **Service Principals** for secure, non-interactive authentication across Terraform, AKS, and CI/CD pipelines.

## Architecture Overview

```
                    ┌─────────────────────────────────────┐
                    │        Bootstrap Resources           │
                    │  rg-bootstrap-<project>-<env>        │
                    │  ┌───────────────────────────────┐   │
                    │  │ Bootstrap Key Vault            │   │
                    │  │  • tf-sp-client-id/secret      │   │
                    │  │  • aks-sp-client-id/secret     │   │
                    │  │  • aks-sp-object-id            │   │
                    │  └───────────────────────────────┘   │
                    └─────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                     Azure Virtual Network (10.0.0.0/16)              │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │  AKS Subnet      │  │  App Subnet      │  │  Database Subnet    │  │
│  │  10.0.1.0/24     │  │  10.0.3.0/24     │  │  10.0.2.0/24       │  │
│  │                   │  │                   │  │                     │  │
│  │  ┌─────────────┐ │  │  ┌─────────────┐ │  │  ┌───────────────┐ │  │
│  │  │ Private AKS │ │  │  │ Linux VM    │ │  │  │ Azure SQL     │ │  │
│  │  │ Cluster     │ │  │  │ (Build Srv) │ │  │  │ (Private EP)  │ │  │
│  │  │  (SP auth)  │ │  │  └─────────────┘ │  │  └───────────────┘ │  │
│  │  │ System: 1   │ │  │  ┌─────────────┐ │  │                     │  │
│  │  │ Worker: 2-4 │ │  │  │ Windows VM  │ │  └─────────────────────┘  │
│  │  │ (autoscale) │ │  │  │ (Access Srv)│ │                           │
│  │  │ NGINX       │ │  │  └─────────────┘ │  ┌─────────────────────┐ │
│  │  │ Ingress LB  │ │  │                   │  │  Bastion Subnet     │ │
│  │  └─────────────┘ │  │  PE: ACR, KV,    │  │  10.0.4.0/26       │ │
│  └─────────────────┘  │  Storage          │  │  Azure Bastion     │ │
│                        └─────────────────┘  └─────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## Authentication Model

This project uses **two Service Principals** (no Managed Identities):

| Service Principal | Purpose | Stored In |
|---|---|---|
| **Terraform SP** (`sp-terraform-<project>-<env>`) | Authenticates Terraform/Terragrunt to create all Azure resources | Bootstrap Key Vault + env vars |
| **AKS SP** (`sp-aks-<project>-<env>`) | AKS cluster identity, ACR Pull/Push, Key Vault access, Storage access | Bootstrap Key Vault → read by shared-services module |

The bootstrap Key Vault is created **once** by `scripts/setup-bootstrap.sh` before any Terraform runs. The shared-services module reads AKS SP credentials from it using `data "azurerm_key_vault_secret"` and passes them to downstream modules.

## Modules

| Module | Resources | Description |
|--------|-----------|-------------|
| **networking** | Resource Group, VNet, 4 Subnets, 3 NSGs, NSG Rules | Core network infrastructure |
| **dns** | 7 Private DNS Zones, VNet Links | DNS resolution for private endpoints and internal services |
| **bastion** | Azure Bastion (Basic), Public IP, Diagnostics | Secure SSH/RDP access to VMs (no public IPs on VMs) |
| **shared-services** | ACR, Key Vault, Storage Account, Log Analytics, Private Endpoints, RBAC | Shared platform services; reads AKS SP creds from bootstrap KV |
| **compute** | Linux VM, Windows VM, Data Disks, NICs, Key Vault Secrets | Build server (Jenkins) and access server |
| **database** | Azure SQL Server (SystemAssigned identity), SQL Database, Private Endpoint, Diagnostics | Managed database with auto-generated credentials in Key Vault |
| **aks** | AKS Private Cluster (SP auth), System Pool (1 node), Worker Pool (2–4 autoscale), Diagnostics | Container orchestration with Standard SKU SLA |

## Dependency Graph

```
networking ──┬── dns
             ├── bastion ──── shared-services
             ├── shared-services ──── dns
             ├── compute ──── shared-services
             ├── database ──── dns, shared-services
             └── aks ──── dns, shared-services
```

> **Note:** The `identity` module has been removed. All modules now use Service Principals instead of User Assigned Managed Identities.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **Azure CLI** | >= 2.50 | Authentication, bootstrap script |
| **Terraform** | >= 1.5.0 | Infrastructure provisioning |
| **Terragrunt** | >= 0.50.0 (or alpha with new CLI) | Module orchestration and dependency management |
| **Git Bash** or **WSL** | Any | Running shell scripts on Windows |
| **Python 3** | Any | JSON parsing in bootstrap script |

You also need:
- An Azure **Pay-As-You-Go** (or sponsored) subscription
- An Azure AD account with **Owner** or **Global Administrator** role (to create SPs and assign roles)
- A **GitHub repository** with Actions enabled (for CI/CD)

---

## New DevOps Engineer Onboarding Guide

Follow these steps **in exact order** when joining the project or setting up infrastructure from scratch.

### Step 0: Clone the Repository

```bash
git clone https://github.com/mrejij/Terraform.git
cd Terraform
```

### Step 1: Install Required Tools

```bash
# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash    # Linux/WSL
# or: winget install Microsoft.AzureCLI                     # Windows

# Terraform
# Download from https://developer.hashicorp.com/terraform/install

# Terragrunt
# Download from https://github.com/gruntwork-io/terragrunt/releases
```

Verify installations:
```bash
az version
terraform version
terragrunt --version
```

### Step 2: Authenticate to Azure

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# Verify
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table
```

Note down the **Subscription ID** and **Tenant ID** from the output.

### Step 3: Set Environment Variables

```bash
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
export ARM_TENANT_ID="<your-tenant-id>"
```

### Step 4: Run the Bootstrap Script

This creates the Terraform SP, AKS SP, and a bootstrap Key Vault to store their credentials:

```bash
cd scripts
bash setup-bootstrap.sh
```

The script will output the remaining environment variables you need. Export them:

```bash
export ARM_CLIENT_ID="<tf-sp-client-id-from-output>"
export ARM_CLIENT_SECRET="<tf-sp-client-secret-from-output>"
export BOOTSTRAP_KEY_VAULT_NAME="kv-boot-3tierapp-dev"
export BOOTSTRAP_RESOURCE_GROUP="rg-bootstrap-3tierapp-dev"
```

> **Tip:** Add these exports to a `.env` file (already in `.gitignore`) for convenience:
> ```bash
> cat > ../.env << 'EOF'
> export ARM_SUBSCRIPTION_ID="..."
> export ARM_TENANT_ID="..."
> export ARM_CLIENT_ID="..."
> export ARM_CLIENT_SECRET="..."
> export BOOTSTRAP_KEY_VAULT_NAME="..."
> export BOOTSTRAP_RESOURCE_GROUP="..."
> EOF
> source ../.env
> ```

### Step 5: Create the Terraform State Backend

```bash
bash setup-backend.sh
```

This creates an Azure Storage Account for Terraform remote state.

### Step 6: Initialize and Deploy Infrastructure

```bash
cd ../environments/dev

# Initialize all modules (downloads providers, configures backend)
terragrunt run --all -- init

# Preview what will be created
terragrunt run --all -- plan

# Deploy everything (Terragrunt handles dependency order automatically)
terragrunt run --all -- apply
```

> **Note on Terragrunt CLI syntax:**
> - Legacy Terragrunt (< 0.56): `terragrunt run-all init`
> - Terragrunt alpha (2026+): `terragrunt run --all -- init`
> - Check your version with `terragrunt --version` and use the matching syntax.

### Step 7: Verify Deployment

```bash
# Check all resources in the resource group
az resource list --resource-group rg-3tierapp-dev-cav -o table

# Get AKS cluster info
az aks show --resource-group rg-3tierapp-dev-cav --name aks-3tierapp-dev-cav --query "{status:provisioningState, version:kubernetesVersion, nodeCount:agentPoolProfiles[].count}" -o table
```

### Step 8: Post-Deployment — Linux VM Setup

Connect to the Linux build server via Azure Bastion, then run the setup script:

```bash
# Copy setup script to the VM (via Bastion tunnel or SCP through Bastion)
# Then on the VM:
bash setup-linux-vm.sh
```

This installs Docker, Azure CLI, kubectl, Helm, k9s, Jenkins, and sqlcmd.

### Step 9: Connect to AKS from the Build Server

From the Linux VM (which has VNet access to the private AKS cluster):

```bash
# Login using the AKS SP (get creds from bootstrap KV)
az login --service-principal \
  -u "$(az keyvault secret show --vault-name kv-boot-3tierapp-dev --name aks-sp-client-id --query value -o tsv)" \
  -p "$(az keyvault secret show --vault-name kv-boot-3tierapp-dev --name aks-sp-client-secret --query value -o tsv)" \
  --tenant "<TENANT_ID>"

# Get AKS credentials
az aks get-credentials --resource-group rg-3tierapp-dev-cav --name aks-3tierapp-dev-cav

# Verify
kubectl get nodes
```

---

## CI/CD with GitHub Actions

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **01 - Setup State Backend** | Manual (`workflow_dispatch`) | Creates Azure Storage for Terraform state (run once) |
| **02 - Terraform Plan** | Pull Request to `master` | Runs plan on every PR, posts output as PR comment |
| **03 - Terraform Apply** | Push to `master` / Manual | Applies infrastructure after PR merge |
| **04 - Terraform Destroy** | Manual (requires `DESTROY` confirmation) | Tears down all infrastructure |

### GitHub Secrets Setup

Add these secrets to your GitHub repository (**Settings > Secrets and variables > Actions**):

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ARM_SUBSCRIPTION_ID` | Azure Subscription ID | `az account show --query id -o tsv` |
| `ARM_TENANT_ID` | Azure AD Tenant ID | `az account show --query tenantId -o tsv` |
| `ARM_CLIENT_ID` | Terraform SP Client ID | Output of `setup-bootstrap.sh` |
| `ARM_CLIENT_SECRET` | Terraform SP Client Secret | Output of `setup-bootstrap.sh` |
| `BOOTSTRAP_KEY_VAULT_NAME` | Bootstrap Key Vault name | `kv-boot-<project>-<env>` |
| `BOOTSTRAP_RESOURCE_GROUP` | Bootstrap RG name | `rg-bootstrap-<project>-<env>` |

### GitHub Environment Protection (Recommended)

1. Go to **Settings > Environments > New environment** and create `prod`
2. Enable **Required reviewers** and add yourself
3. The apply and destroy workflows reference this environment, so deployments require approval

### Workflow Execution Order

```
Step 1: Run "01 - Setup State Backend" manually (Actions tab → Run workflow)
Step 2: Create a feature branch, push changes, open a PR → "02 - Terraform Plan" runs
Step 3: Review plan in PR comments, approve and merge → "03 - Terraform Apply" runs
Step 4: (if needed) Run "04 - Terraform Destroy" manually to tear down
```

---

## Deploying Individual Modules

If you need to deploy or troubleshoot a single module:

```bash
cd environments/dev/networking
terragrunt init
terragrunt plan
terragrunt apply
```

Deploy in dependency order:
```
1. networking
2. dns
3. shared-services  (depends on networking, dns)
4. bastion          (depends on networking, shared-services)
5. compute          (depends on networking, shared-services)
6. database         (depends on networking, dns, shared-services)
7. aks              (depends on networking, dns, shared-services) — deploy last
```

---

## Destroying Infrastructure

### Local

```bash
cd environments/dev
terragrunt run --all -- destroy -auto-approve
```

### Via GitHub Actions

1. Go to **Actions > 04 - Terraform Destroy**
2. Click **Run workflow**
3. Select the environment and type `DESTROY` to confirm

> **Important:** The bootstrap Key Vault and state backend are **not** destroyed by Terragrunt. Delete them manually if needed:
> ```bash
> az group delete --name rg-bootstrap-3tierapp-dev --yes
> az group delete --name rg-tfstate-3tierapp-dev --yes
> ```

---

## Post-Deployment Steps

### Deploy NGINX Ingress Controller

From the Linux build server (via Bastion):

```bash
# Add NGINX Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX ingress with internal load balancer
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"="true" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal-subnet"="snet-aks-3tierapp-dev" \
  --set controller.replicaCount=2

# Get the internal LB IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Add Wildcard DNS Record

```bash
az network private-dns record-set a add-record \
  --resource-group rg-3tierapp-dev-cav \
  --zone-name svc.cluster.internal \
  --record-set-name "*" \
  --ipv4-address <NGINX_LB_IP>
```

### Retrieve Secrets from Key Vault

```bash
KV_NAME=$(az keyvault list --resource-group rg-3tierapp-dev-cav --query "[0].name" -o tsv)

# SSH private key for Linux VM
az keyvault secret show --vault-name $KV_NAME --name linux-ssh-private-key --query value -o tsv

# Windows admin password
az keyvault secret show --vault-name $KV_NAME --name windows-admin-password --query value -o tsv

# SQL connection string
az keyvault secret show --vault-name $KV_NAME --name sql-connection-string --query value -o tsv
```

---

## Security Features

- **Service Principal authentication** — no user credentials or interactive login in CI/CD
- **Bootstrap Key Vault** — SP secrets stored securely, never in code or environment files
- **Private AKS cluster** — API server not publicly accessible
- **Private endpoints** on all PaaS services (ACR, Key Vault, Storage, SQL)
- **Private DNS zones** — secure DNS resolution within the VNet
- **NSG rules** — deny-all default on database subnet, least-privilege inbound rules
- **Azure Bastion** — secure VM access with no public IPs on VMs
- **Key Vault RBAC** — role-based access control with Deny default + IP allowlisting
- **TLS 1.2** minimum on all services
- **Auto-generated passwords** — SQL and Windows VM credentials stored in Key Vault
- **SSH key authentication** — Linux VM password auth disabled
- **Diagnostic logging** — all resources send logs to Log Analytics
- **AKS Standard SKU** — SLA-backed control plane with autoscaling worker pool (2–4 nodes)

---

## Environment Configuration

### Dev vs Prod Differences

| Setting | Dev | Prod |
|---------|-----|------|
| Key Vault public access | Enabled (deployer IP allowlisted) | Disabled (PE-only) |
| Storage replication | LRS | GRS |
| Log retention | 30 days | 90 days |
| SQL SKU | S0 (10 GB) | S1 (50 GB) |
| SQL backup retention | 7 days | 14 days |
| AKS worker autoscale | 2–4 nodes | 2–4 nodes |
| AKS SKU tier | Standard | Standard |

### Adding a New Environment

1. Copy `environments/dev/` to `environments/<env>/`
2. Update `env.hcl` with the new project name, environment, location, and location short code
3. Adjust resource sizing in each module's `terragrunt.hcl`
4. Run `setup-bootstrap.sh` with updated variables for the new environment
5. Run `setup-backend.sh` for the new state backend
6. Deploy: `cd environments/<env> && terragrunt run --all -- apply`

---

## File Structure

```
.
├── .gitignore                              # Excludes cache, state, secrets
├── terragrunt.hcl                          # Root config (SP auth, remote state, common inputs)
├── README.md
├── .github/workflows/
│   ├── 01-setup-backend.yml                # One-time state backend setup
│   ├── 02-terraform-plan.yml               # PR plan + comment
│   ├── 03-terraform-apply.yml              # Apply on merge
│   └── 04-terraform-destroy.yml            # Manual destroy with confirmation
├── scripts/
│   ├── setup-bootstrap.sh                  # Creates SPs + bootstrap Key Vault (run first)
│   ├── setup-backend.sh                    # Creates state backend storage (run second)
│   ├── setup-backend.ps1                   # PowerShell version of backend setup
│   └── setup-linux-vm.sh                   # Installs tools on Linux build server
├── modules/
│   ├── networking/                         # VNet, Subnets, NSGs
│   ├── dns/                                # Private DNS Zones
│   ├── bastion/                            # Azure Bastion
│   ├── shared-services/                    # ACR, KV, Storage, Log Analytics + reads AKS SP from bootstrap KV
│   ├── compute/                            # Linux + Windows VMs
│   ├── database/                           # Azure SQL (SystemAssigned identity)
│   └── aks/                                # AKS Private Cluster (SP auth, autoscaling worker pool)
└── environments/
    ├── dev/
    │   ├── env.hcl                         # project=3tierapp, env=dev, location=centralindia
    │   ├── networking/terragrunt.hcl
    │   ├── dns/terragrunt.hcl
    │   ├── bastion/terragrunt.hcl
    │   ├── shared-services/terragrunt.hcl
    │   ├── compute/terragrunt.hcl
    │   ├── database/terragrunt.hcl
    │   └── aks/terragrunt.hcl
    └── prod/
        ├── env.hcl                         # project=threetier, env=prod, location=eastus
        ├── networking/terragrunt.hcl
        ├── dns/terragrunt.hcl
        ├── bastion/terragrunt.hcl
        ├── shared-services/terragrunt.hcl
        ├── compute/terragrunt.hcl
        ├── database/terragrunt.hcl
        └── aks/terragrunt.hcl
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `AADSTS700016: Application not found` | Terraform SP not created yet — run `setup-bootstrap.sh` |
| `Key Vault 403 Forbidden` | SP doesn't have RBAC on KV — check role assignments or add deployer IP to KV firewall |
| `AuthorizationFailed` on resource creation | Terraform SP needs **Contributor** + **User Access Administrator** on the subscription |
| `SkuNotAvailable` for VM size | Change `system_node_vm_size` / `worker_node_vm_size` in the environment's `aks/terragrunt.hcl` |
| Mock output errors during `init` | Ensure `mock_outputs_allowed_terraform_commands` includes `"init"` in the env terragrunt.hcl |
| `terragrunt run-all` not recognized | You may be on legacy Terragrunt — use `terragrunt run --all --` syntax for alpha versions |
