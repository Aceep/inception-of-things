#!/bin/bash

# =============================================================================
# install.sh - Install all required tools for k3d/k3s project
# =============================================================================
# This script installs:
#   - Docker (container runtime for k3d)
#   - k3d (k3s in Docker)
#   - kubectl (Kubernetes CLI)
#   - Argo CD CLI
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 1. Install Docker
# -----------------------------------------------------------------------------
install_docker() {
    log_info "Checking Docker installation..."
    
    if check_command docker; then
        log_success "Docker is already installed: $(docker --version)"
        return 0
    fi
    
    log_info "Installing Docker..."
    
    # Remove old versions if any
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group (to run docker without sudo)
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker installed successfully!"
    log_warning "You may need to log out and back in for group changes to take effect."
    log_warning "Or run: newgrp docker"
}

# -----------------------------------------------------------------------------
# 2. Install k3d
# -----------------------------------------------------------------------------
install_k3d() {
    log_info "Checking k3d installation..."
    
    if check_command k3d; then
        log_success "k3d is already installed: $(k3d --version)"
        return 0
    fi
    
    log_info "Installing k3d..."
    
    # Install k3d using the official install script
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    
    log_success "k3d installed successfully: $(k3d --version)"
}

# -----------------------------------------------------------------------------
# 3. Install kubectl
# -----------------------------------------------------------------------------
install_kubectl() {
    log_info "Checking kubectl installation..."
    
    if check_command kubectl; then
        log_success "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi
    
    log_info "Installing kubectl..."
    
    # Download the latest stable version
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl installed successfully: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# -----------------------------------------------------------------------------
# 4. Install Argo CD CLI
# -----------------------------------------------------------------------------
install_argocd_cli() {
    log_info "Checking Argo CD CLI installation..."
    
    if check_command argocd; then
        log_success "Argo CD CLI is already installed: $(argocd version --client 2>/dev/null | head -1)"
        return 0
    fi
    
    log_info "Installing Argo CD CLI..."
    
    # Get the latest version
    ARGOCD_VERSION=$(curl -L -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    # Download and install
    curl -sSL -o argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    
    log_success "Argo CD CLI installed successfully: $(argocd version --client 2>/dev/null | head -1)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo "=============================================="
    echo "   K3d/K3s Project - Installation Script"
    echo "=============================================="
    echo ""
    
    # Check if running as root (not recommended for Docker)
    if [ "$EUID" -eq '0' ]; then
        log_warning "Running as root. Docker group membership won't be configured."
    fi
    
    # Install all components
    install_docker
    echo ""
    install_k3d
    echo ""
    install_kubectl
    echo ""
    install_argocd_cli
    echo ""
    
    echo "=============================================="
    log_success "All tools installed successfully!"
    echo "=============================================="
    echo ""
    echo "Installed versions:"
    echo "  - Docker:    $(docker --version 2>/dev/null || echo 'restart shell to verify')"
    echo "  - k3d:       $(k3d --version 2>/dev/null || echo 'restart shell to verify')"
    echo "  - kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1 || echo 'restart shell to verify')"
    echo "  - argocd:    $(argocd version --client 2>/dev/null | head -1 || echo 'restart shell to verify')"
    echo ""
    log_info "If this is a fresh Docker install, please run: newgrp docker"
    log_info "Or log out and log back in for group changes to take effect."
    echo ""
}

main "$@"
