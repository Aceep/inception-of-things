#!/bin/bash

# =============================================================================
# setup.sh - Setup k3d cluster with Argo CD and dev namespace
# =============================================================================
# This script:
#   1. Creates a k3d cluster
#   2. Creates 'argocd' namespace and installs Argo CD
#   3. Creates 'dev' namespace
#   4. Configures Argo CD application to deploy from GitHub
# =============================================================================

set -e  # Exit on error

# Configuration
CLUSTER_NAME="iot-cluster"
ARGOCD_NAMESPACE="argocd"
DEV_NAMESPACE="dev"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo ""
    echo -e "${CYAN}=============================================="
    echo -e "  $1"
    echo -e "==============================================${NC}"
    echo ""
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}  # Default 5 minutes
    
    log_info "Waiting for all pods in namespace '$namespace' to be ready (timeout: ${timeout}s)..."
    
    kubectl wait --for=condition=Ready pods --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null || {
        log_warning "Some pods may not be ready yet. Checking status..."
        kubectl get pods -n "$namespace"
    }
}

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
preflight_checks() {
    log_step "Pre-flight Checks"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Run ./install.sh first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker."
        log_info "Try: sudo systemctl start docker"
        exit 1
    fi
    
    # Check k3d
    if ! command -v k3d &> /dev/null; then
        log_error "k3d is not installed. Run ./install.sh first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Run ./install.sh first."
        exit 1
    fi
    
    log_success "All pre-flight checks passed!"
}

# -----------------------------------------------------------------------------
# 1. Create k3d cluster
# -----------------------------------------------------------------------------
create_cluster() {
    log_step "Step 1: Creating k3d Cluster"
    
    # Check if cluster already exists
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        log_warning "Cluster '$CLUSTER_NAME' already exists."
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deleting existing cluster..."
            k3d cluster delete "$CLUSTER_NAME"
        else
            log_info "Using existing cluster."
            return 0
        fi
    fi
    
    log_info "Creating k3d cluster '$CLUSTER_NAME'..."
    
    # Create cluster with port mappings
    # - Port 8081 for HTTP ingress
    # - Port 8443 for HTTPS ingress
    k3d cluster create "$CLUSTER_NAME" \
        --servers 1 \
        --agents 2 \
        --port "8081:80@loadbalancer" \
        --port "8443:443@loadbalancer" \
        --wait
    
    # Verify cluster is running
    log_info "Verifying cluster status..."
    kubectl cluster-info
    
    log_success "Cluster '$CLUSTER_NAME' created successfully!"
    
    # Show nodes
    log_info "Cluster nodes:"
    kubectl get nodes
}

# -----------------------------------------------------------------------------
# 2. Create namespaces
# -----------------------------------------------------------------------------
create_namespaces() {
    log_step "Step 2: Creating Namespaces"
    
    # Create argocd namespace
    log_info "Creating namespace '$ARGOCD_NAMESPACE'..."
    kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create dev namespace
    log_info "Creating namespace '$DEV_NAMESPACE'..."
    kubectl create namespace "$DEV_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Namespaces created successfully!"
    kubectl get namespaces
}

# -----------------------------------------------------------------------------
# 3. Install Argo CD
# -----------------------------------------------------------------------------
install_argocd() {
    log_step "Step 3: Installing Argo CD"
    
    log_info "Installing Argo CD in namespace '$ARGOCD_NAMESPACE'..."
    
    # Install Argo CD using the official manifest
    kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    log_info "Waiting for Argo CD pods to be ready..."
    sleep 10  # Give it some time to create the pods
    
    # Wait for all Argo CD pods to be ready
    wait_for_pods "$ARGOCD_NAMESPACE" 300
    
    log_success "Argo CD installed successfully!"
    
    # Show Argo CD pods
    log_info "Argo CD pods:"
    kubectl get pods -n "$ARGOCD_NAMESPACE"
}

# -----------------------------------------------------------------------------
# 4. Configure Argo CD access
# -----------------------------------------------------------------------------
configure_argocd_access() {
    log_step "Step 4: Configuring Argo CD Access"
    
    # Get initial admin password
    log_info "Retrieving Argo CD admin password..."
    
    # Wait for the secret to be created
    while ! kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" &> /dev/null; do
        log_info "Waiting for admin secret to be created..."
        sleep 5
    done
    
    ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Argo CD Credentials:${NC}"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo "=============================================="
    echo ""
    
    # Save credentials to a file
    echo "Username: admin" > "$PROJECT_DIR/argocd-credentials.txt"
    echo "Password: $ARGOCD_PASSWORD" >> "$PROJECT_DIR/argocd-credentials.txt"
    log_info "Credentials saved to: $PROJECT_DIR/argocd-credentials.txt"
    
    # Patch Argo CD server to use LoadBalancer or NodePort for easier access
    log_info "Patching Argo CD server service for external access..."
    kubectl patch svc argocd-server -n "$ARGOCD_NAMESPACE" -p '{"spec": {"type": "NodePort"}}'
    
    log_success "Argo CD access configured!"
}

# -----------------------------------------------------------------------------
# 5. Deploy Argo CD Application
# -----------------------------------------------------------------------------
deploy_argocd_application() {
    log_step "Step 5: Deploying Argo CD Application"
    
    # Check if application config exists
    if [ -f "$PROJECT_DIR/confs/argocd/application.yaml" ]; then
        log_info "Applying Argo CD application configuration..."
        kubectl apply -f "$PROJECT_DIR/confs/argocd/application.yaml"
        log_success "Argo CD application deployed!"
    else
        log_warning "Application configuration not found at: $PROJECT_DIR/confs/argocd/application.yaml"
        log_info "Please create the application configuration file and run:"
        log_info "  kubectl apply -f $PROJECT_DIR/confs/argocd/application.yaml"
    fi
}

# -----------------------------------------------------------------------------
# 6. Show access information
# -----------------------------------------------------------------------------
show_access_info() {
    log_step "Setup Complete!"
    
    echo "=============================================="
    echo -e "${GREEN}Access Information:${NC}"
    echo "=============================================="
    echo ""
    
    # Get Argo CD NodePort
    ARGOCD_PORT=$(kubectl get svc argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    
    echo "Argo CD UI:"
    echo "  - Port-forward method (recommended):"
    echo "    kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8081:443"
    echo "    Then access: https://localhost:8081"
    echo ""
    echo "  - NodePort method:"
    echo "    Access: https://localhost:$ARGOCD_PORT"
    echo ""
    echo "Credentials:"
    echo "  Username: admin"
    echo "  Password: $(cat "$PROJECT_DIR/argocd-credentials.txt" | grep Password | cut -d' ' -f2)"
    echo ""
    echo "Useful commands:"
    echo "  - Check cluster:     kubectl cluster-info"
    echo "  - Check nodes:       kubectl get nodes"
    echo "  - Check namespaces:  kubectl get ns"
    echo "  - Check Argo CD:     kubectl get pods -n $ARGOCD_NAMESPACE"
    echo "  - Check dev apps:    kubectl get all -n $DEV_NAMESPACE"
    echo "  - Delete cluster:    k3d cluster delete $CLUSTER_NAME"
    echo ""
    echo "=============================================="
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=============================================="
    echo "   K3d/K3s Project - Setup Script"
    echo "=============================================="
    echo ""
    
    preflight_checks
    create_cluster
    create_namespaces
    install_argocd
    configure_argocd_access
    deploy_argocd_application
    show_access_info
}

main "$@"
