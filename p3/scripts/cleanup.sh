#!/bin/bash

# =============================================================================
# cleanup.sh - Clean up the k3d cluster and resources
# =============================================================================

set -e

# Configuration
CLUSTER_NAME="iot-cluster"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "=============================================="
echo "   K3d/K3s Project - Cleanup Script"
echo "=============================================="
echo ""

# Check if cluster exists
if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    log_info "Found cluster '$CLUSTER_NAME'"
    
    read -p "Are you sure you want to delete the cluster? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deleting k3d cluster '$CLUSTER_NAME'..."
        k3d cluster delete "$CLUSTER_NAME"
        log_success "Cluster deleted!"
    else
        log_info "Cluster deletion cancelled."
    fi
else
    log_warning "Cluster '$CLUSTER_NAME' not found."
fi

# Clean up generated files
if [ -f "$PROJECT_DIR/argocd-credentials.txt" ]; then
    log_info "Removing credentials file..."
    rm -f "$PROJECT_DIR/argocd-credentials.txt"
    log_success "Credentials file removed."
fi

echo ""
log_success "Cleanup complete!"
echo ""
