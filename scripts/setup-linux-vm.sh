#!/usr/bin/env bash
# =====================================================================================================================
# LINUX BUILD SERVER SETUP
# Installs: Docker, Azure CLI, kubectl, Helm, k9s, Jenkins, sqlcmd
# Run as: azureadmin on the Linux VM after SSH-ing in
# Usage: bash setup-linux-vm.sh
# =====================================================================================================================

set -euo pipefail

KUBECTL_K8S_VERSION="v1.35"
DATA_DISK_DEVICE="/dev/sdb"
DATA_MOUNT_POINT="/data"

echo "==========================================="
echo "  Linux Build Server Setup"
echo "==========================================="

# ─────────────────────────────────────────────────────────────────────────────
# MOUNT DATA DISK
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[1/8] Mounting data disk..."
if mountpoint -q "${DATA_MOUNT_POINT}"; then
    echo "  Data disk already mounted at ${DATA_MOUNT_POINT}. Skipping."
elif mount | grep -q "${DATA_DISK_DEVICE}"; then
    echo "  ${DATA_DISK_DEVICE} is already mounted elsewhere. Skipping."
else
    echo "  Using data disk: ${DATA_DISK_DEVICE}"

    # Partition the disk if no partition exists
    if ! ls "${DATA_DISK_DEVICE}"1 &>/dev/null; then
        echo "  Creating partition on ${DATA_DISK_DEVICE}..."
        sudo parted "${DATA_DISK_DEVICE}" --script mklabel gpt mkpart primary ext4 0% 100%
        sleep 2
    fi

    PARTITION="${DATA_DISK_DEVICE}1"

    # Format if no filesystem found
    if ! blkid "${PARTITION}" &>/dev/null; then
        echo "  Formatting ${PARTITION}..."
        sudo mkfs.ext4 "${PARTITION}"
    fi

    sudo mkdir -p "${DATA_MOUNT_POINT}"
    sudo mount "${PARTITION}" "${DATA_MOUNT_POINT}"

    if ! grep -q "${PARTITION}" /etc/fstab; then
        echo "${PARTITION} ${DATA_MOUNT_POINT} ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo chown -R "$(whoami):$(whoami)" "${DATA_MOUNT_POINT}"
    echo "  Data disk mounted at ${DATA_MOUNT_POINT}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM UPDATE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[2/8] Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https unzip

# ─────────────────────────────────────────────────────────────────────────────
# DOCKER
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[3/8] Installing Docker..."
if ! command -v docker &>/dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$(whoami)"
    echo "  Docker installed. Log out and back in for group changes to take effect."
else
    echo "  Docker already installed: $(docker --version)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# AZURE CLI
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[4/8] Installing Azure CLI..."
if ! command -v az &>/dev/null; then
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    echo "  Azure CLI installed."
else
    echo "  Azure CLI already installed: $(az version --query '\"azure-cli\"' -o tsv)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# KUBECTL
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[5/8] Installing kubectl (${KUBECTL_K8S_VERSION})..."
if ! command -v kubectl &>/dev/null; then
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBECTL_K8S_VERSION}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBECTL_K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt update
    sudo apt install -y kubectl
    echo "  kubectl installed."
else
    echo "  kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# HELM
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[6/8] Installing Helm..."
if ! command -v helm &>/dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "  Helm installed."
else
    echo "  Helm already installed: $(helm version --short)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# K9S
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[7/8] Installing k9s..."
if ! command -v k9s &>/dev/null; then
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin k9s
    echo "  k9s ${K9S_VERSION} installed."
else
    echo "  k9s already installed: $(k9s version --short 2>/dev/null || echo 'installed')"
fi

# ─────────────────────────────────────────────────────────────────────────────
# JENKINS
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[8/8] Installing Jenkins..."
if ! command -v jenkins &>/dev/null && ! systemctl is-active --quiet jenkins 2>/dev/null; then
    # Java 21 (required by Jenkins)
    sudo apt install -y fontconfig openjdk-21-jre

    # Jenkins repo — fetch signing key by ID from keyserver (jenkins.io-2023.key is outdated)
    sudo gpg --no-default-keyring --keyring /usr/share/keyrings/jenkins-keyring.gpg --keyserver keyserver.ubuntu.com --recv-keys 7198F4B714ABFC68
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt update
    sudo apt install -y jenkins

    # Move Jenkins home to data disk
    sudo systemctl stop jenkins
    if [ ! -d "${DATA_MOUNT_POINT}/jenkins" ]; then
        sudo mv /var/lib/jenkins "${DATA_MOUNT_POINT}/jenkins"
    fi
    sudo ln -sfn "${DATA_MOUNT_POINT}/jenkins" /var/lib/jenkins

    # Start Jenkins
    sudo systemctl enable jenkins
    sudo systemctl start jenkins
    echo "  Jenkins installed and running on port 8080."
else
    echo "  Jenkins already installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
# SQL CLIENT (sqlcmd)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[bonus] Installing sqlcmd..."
if ! command -v sqlcmd &>/dev/null; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null
    sudo add-apt-repository -y "$(wget -qO- https://packages.microsoft.com/config/ubuntu/22.04/prod.list)"
    sudo apt update
    sudo apt install -y mssql-tools18 unixodbc-dev

    if ! grep -q '/opt/mssql-tools18/bin' ~/.bashrc; then
        echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
    fi
    echo "  sqlcmd installed. Run 'source ~/.bashrc' or re-login to use it."
else
    echo "  sqlcmd already installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==========================================="
echo "  Setup Complete!"
echo "==========================================="
echo ""
echo "Installed tools:"
echo "  Docker       : $(docker --version 2>/dev/null || echo 'restart shell for docker group')"
echo "  Azure CLI    : $(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo 'installed')"
echo "  kubectl      : $(kubectl version --client --short 2>/dev/null || echo 'installed')"
echo "  Helm         : $(helm version --short 2>/dev/null || echo 'installed')"
echo "  k9s          : $(k9s version --short 2>/dev/null || echo 'installed')"
echo "  Jenkins      : $(systemctl is-active jenkins 2>/dev/null || echo 'installed')"
echo "  sqlcmd       : $(/opt/mssql-tools18/bin/sqlcmd '-?' 2>&1 | head -1 || echo 'installed')"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for Docker group)"
echo "  2. Get Jenkins initial password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "  3. Access Jenkins: http://<PUBLIC_IP>:8080"
echo "  4. Connect to AKS: az login --identity && az aks get-credentials -g rg-3tierapp-dev-cav -n aks-3tierapp-dev-cav"
echo "  5. Verify: kubectl get nodes"
