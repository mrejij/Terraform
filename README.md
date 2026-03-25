# 3-Tier Production-Grade Azure Infrastructure

Production-ready Infrastructure as Code for a 3-tier application (Angular frontend, ASP.NET backend, SQL Server database) running on Azure Kubernetes Service.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Azure Virtual Network (10.0.0.0/16)           │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │
│  │  AKS Subnet      │  │  App Subnet      │  │  Database Subnet    │  │
│  │  10.0.1.0/24     │  │  10.0.3.0/24     │  │  10.0.2.0/24       │  │
│  │                   │  │                   │  │                     │  │
│  │  ┌─────────────┐ │  │  ┌─────────────┐ │  │  ┌───────────────┐ │  │
│  │  │ Private AKS │ │  │  │ Linux VM    │ │  │  │ Azure SQL     │ │  │
│  │  │ Cluster     │ │  │  │ (Build Srv) │ │  │  │ (Private EP)  │ │  │
│  │  │             │ │  │  └─────────────┘ │  │  └───────────────┘ │  │
│  │  │ System Pool │ │  │  ┌─────────────┐ │  │                     │  │
│  │  │ Worker Pool │ │  │  │ Windows VM  │ │  └─────────────────────┘  │
│  │  │             │ │  │  │ (Access Srv)│ │                           │
│  │  │ NGINX       │ │  │  └─────────────┘ │  ┌─────────────────────┐ │
│  │  │ Ingress LB  │ │  │                   │  │  Bastion Subnet     │ │
│  │  └─────────────┘ │  │  PE: ACR, KV,    │  │  10.0.4.0/26       │ │
│  └─────────────────┘  │  Storage          │  │  Azure Bastion     │ │
│                        └─────────────────┘  └─────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## Modules

| Module | Resources | Description |
|--------|-----------|-------------|
| **networking** | Resource Group, VNet, 4 Subnets, 3 NSGs, NSG Rules | Core network infrastructure |
| **identity** | User Assigned Managed Identity, Role Assignments | Single identity for all inter-service communication |
| **dns** | 7 Private DNS Zones, VNet Links | DNS resolution for private endpoints and internal services |
| **bastion** | Azure Bastion (Standard), Public IP | Secure SSH/RDP access to VMs |
| **shared-services** | ACR, Key Vault, Storage Account, Log Analytics, Private Endpoints | Shared platform services |
| **compute** | Linux VM, Windows VM, Data Disk, NICs | Build and access servers |
| **database** | Azure SQL Server, SQL Database, Private Endpoint | Managed database service |
| **aks** | AKS Private Cluster, System + Worker Node Pools, Diagnostics | Container orchestration |

## Dependency Graph

```
networking ──┬── identity
             ├── dns
             ├── bastion (also depends on shared-services)
             ├── shared-services (depends on identity, dns)
             ├── compute (depends on identity, shared-services)
             ├── database (depends on identity, dns, shared-services)
             └── aks (depends on identity, dns, shared-services)
```

## Prerequisites

1. **Azure CLI** installed and authenticated (`az login`)
2. **Terraform** >= 1.5.0
3. **Terragrunt** >= 0.50.0
4. An Azure subscription with sufficient quotas
5. **GitHub repository** with Actions enabled (for CI/CD)

## CI/CD with GitHub Actions

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **01 - Setup State Backend** | Manual (`workflow_dispatch`) | Creates Azure Storage for Terraform state (run once) |
| **02 - Terraform Plan** | Pull Request to `main` | Runs plan on every PR, posts output as PR comment |
| **03 - Terraform Apply** | Push to `main` / Manual | Applies infrastructure after PR merge |
| **04 - Terraform Destroy** | Manual (requires `DESTROY` confirmation) | Tears down all infrastructure |

### GitHub Secrets Setup

Add these 4 secrets to your GitHub repository under **Settings > Secrets and variables > Actions**:

| Secret Name | Description |
|-------------|-------------|
| `AZURE_USERNAME` | Your Azure login email (e.g., `user@domain.onmicrosoft.com`) |
| `AZURE_PASSWORD` | Your Azure account password |
| `ARM_TENANT_ID` | Azure AD Tenant ID (find via `az account show --query tenantId -o tsv`) |
| `ARM_SUBSCRIPTION_ID` | Azure Subscription ID (find via `az account show --query id -o tsv`) |

> **Important notes for free trial with user credentials:**
> - MFA (Multi-Factor Authentication) **must be disabled** on the account for `az login -u -p` to work in CI
> - Go to Azure Portal > **Microsoft Entra ID > Security > MFA > Per-user MFA** and set your user to **Disabled**
> - This uses your personal admin credentials — keep the GitHub repo **private**
> - The workflows authenticate via `az login -u <email> -p <password>` and Terraform uses the CLI session

### GitHub Environment Protection (Recommended)

1. Go to **Settings > Environments > New environment** and create `prod`
2. Enable **Required reviewers** and add yourself
3. The apply and destroy workflows reference this environment, so deployments will require your approval

### Workflow Execution Order

```
Step 1: Run "01 - Setup State Backend" manually (Actions tab > Run workflow)
Step 2: Create a feature branch, push changes, open a PR → "02 - Terraform Plan" runs automatically
Step 3: Review the plan in PR comments, approve and merge → "03 - Terraform Apply" runs automatically
Step 4: (Optional) Run "04 - Terraform Destroy" manually to tear down
```

## Local Quick Start

### 1. Create the Remote State Backend

```powershell
cd scripts
.\setup-backend.ps1 -Project "threetier" -Environment "prod" -Location "eastus"
```

### 2. Deploy All Modules

```powershell
cd environments/prod
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply
```

### 3. Deploy Individual Modules

```powershell
cd environments/prod/networking
terragrunt apply

cd ../identity
terragrunt apply

cd ../dns
terragrunt apply

# ... continue in dependency order
```

### 4. Destroy Infrastructure

```powershell
cd environments/prod
terragrunt run-all destroy
```

## Post-Deployment Steps

### Deploy NGINX Ingress Controller

After AKS is provisioned, connect to the Linux build server via Bastion and deploy NGINX ingress:

```bash
# Get AKS credentials (from build server, which has VNet access to private AKS)
az aks get-credentials --resource-group rg-threetier-prod-eus --name aks-threetier-prod-eus

# Add NGINX Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX ingress with internal load balancer
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"="true" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal-subnet"="snet-aks-threetier-prod" \
  --set controller.replicaCount=2

# Get the internal LB IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Add Wildcard DNS Record

Once you have the NGINX ingress LB IP, create the wildcard DNS record:

```bash
# Replace <LB_IP> with the actual internal load balancer IP
az network private-dns record-set a add-record \
  --resource-group rg-threetier-prod-eus \
  --zone-name svc.cluster.internal \
  --record-set-name "*" \
  --ipv4-address <LB_IP>
```

### Retrieve Secrets from Key Vault

```bash
# SSH private key for Linux VM
az keyvault secret show --vault-name <kv-name> --name linux-ssh-private-key --query value -o tsv

# Windows password
az keyvault secret show --vault-name <kv-name> --name windows-admin-password --query value -o tsv

# SQL connection string
az keyvault secret show --vault-name <kv-name> --name sql-connection-string --query value -o tsv
```

## Security Features

- **Private AKS cluster** - API server not publicly accessible
- **Private endpoints** on all PaaS services (ACR, Key Vault, Storage, SQL)
- **Private DNS zones** for secure DNS resolution
- **NSG rules** with deny-all default on database subnet
- **Azure Bastion** for secure VM access (no public IPs on VMs)
- **Key Vault** with RBAC authorization and purge protection
- **TLS 1.2** minimum on all services
- **Managed Identity** - no credentials stored in code
- **Auto-generated passwords** for SQL and Windows VM, stored in Key Vault
- **SSH key authentication** for Linux VM (password auth disabled)
- **Diagnostic logging** to Log Analytics for audit and monitoring
- **Zone-redundant** ACR and AKS node pools

## Adding a New Environment

1. Copy `environments/prod/` to `environments/<env>/`
2. Update `env.hcl` with new environment values
3. Adjust resource sizing in each module's `terragrunt.hcl`
4. Run `terragrunt run-all apply` from the new environment directory

## File Structure

```
.
├── terragrunt.hcl                          # Root Terragrunt config
├── README.md
├── .github/workflows/
│   ├── 01-setup-backend.yml                # One-time state backend setup
│   ├── 02-terraform-plan.yml               # PR plan + comment
│   ├── 03-terraform-apply.yml              # Apply on merge to main
│   └── 04-terraform-destroy.yml            # Manual destroy with confirmation
├── scripts/
│   └── setup-backend.ps1                   # State backend provisioning (local)
├── modules/
│   ├── networking/                         # VNet, Subnets, NSGs
│   ├── bastion/                            # Azure Bastion
│   ├── identity/                           # Managed Identity
│   ├── dns/                                # Private DNS Zones
│   ├── shared-services/                    # ACR, KV, Storage, Log Analytics
│   ├── compute/                            # Linux + Windows VMs
│   ├── database/                           # Azure SQL
│   └── aks/                                # AKS Private Cluster
└── environments/
    └── prod/
        ├── env.hcl                         # Environment variables
        ├── networking/terragrunt.hcl
        ├── identity/terragrunt.hcl
        ├── dns/terragrunt.hcl
        ├── bastion/terragrunt.hcl
        ├── shared-services/terragrunt.hcl
        ├── compute/terragrunt.hcl
        ├── database/terragrunt.hcl
        └── aks/terragrunt.hcl
```
