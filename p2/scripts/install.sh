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
#   Install kubectl
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
# Main
# -----------------------------------------------------------------------------
main() {
    echo "=============================================="
    echo "      Project - Installation Script"
    echo "=============================================="
    echo ""
    
    # Check if running as root (not recommended for Docker)
    if [ "$EUID" -eq '0' ]; then
        log_warning "Running as root. Docker group membership won't be configured."
    fi
    
    # Install all components
    install_kubectl
    echo ""
    
    echo "=============================================="
    log_success "All tools installed successfully!"
    echo "=============================================="
    echo ""
    echo "Installed versions:"
    echo "  - kubectl:   $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1 || echo 'restart shell to verify')"
    echo ""
    log_info "If this is a fresh Docker install, please run: newgrp docker"
    log_info "Or log out and log back in for group changes to take effect."
    echo ""
}

main "$@"
