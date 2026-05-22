#!/bin/bash

# Flux CD Bootstrap Script for Kubernetes Cluster
# This script automates the installation and configuration of Flux CD

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl found: $(kubectl version --client --short)"
    
    # Check flux
    if ! command -v flux &> /dev/null; then
        print_error "Flux CLI not found. Installing..."
        curl -s https://fluxcd.io/install.sh | sudo bash
    fi
    print_success "flux found: $(flux --version)"
    
    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git not found. Please install git first."
        exit 1
    fi
    print_success "git found: $(git --version)"
    
    # Check GitHub token
    if [[ -z "$GITHUB_TOKEN" ]]; then
        print_error "GITHUB_TOKEN environment variable not set"
        print_info "Set it using: export GITHUB_TOKEN=<your-token>"
        exit 1
    fi
    print_success "GITHUB_TOKEN is set"
    
    # Check GitHub user
    if [[ -z "$GITHUB_USER" ]]; then
        print_error "GITHUB_USER environment variable not set"
        print_info "Set it using: export GITHUB_USER=<your-username>"
        exit 1
    fi
    print_success "GITHUB_USER is set: $GITHUB_USER"
    
    # Check GitHub repo
    if [[ -z "$GITHUB_REPO" ]]; then
        print_warning "GITHUB_REPO not set, using default: gitops-flux-cd"
        GITHUB_REPO="gitops-flux-cd"
    fi
    print_success "GITHUB_REPO is set: $GITHUB_REPO"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_success "Connected to cluster"
    
    # Get cluster info
    CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep "Server" | awk '{print $3}')
    print_success "Cluster version: $CLUSTER_VERSION"
}

# Run pre-flight checks
run_preflightchecks() {
    print_header "Running Flux Pre-flight Checks"
    
    if flux check --pre 2>&1 | grep -q "passed"; then
        print_success "Pre-flight checks passed"
    else
        print_warning "Some pre-flight checks failed, but continuing..."
        flux check --pre || true
    fi
}

# Install Flux components
install_flux() {
    print_header "Installing Flux CD Components"
    
    # Create namespace
    print_info "Creating flux-system namespace..."
    kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace created"
    
    # Create GitHub credentials secret
    print_info "Creating GitHub credentials secret..."
    kubectl create secret generic flux-system \
        --from-literal=username=git \
        --from-literal=password=$GITHUB_TOKEN \
        -n flux-system \
        --dry-run=client -o yaml | kubectl apply -f -
    print_success "Secret created"
    
    # Bootstrap Flux
    print_info "Bootstrapping Flux (this may take a few minutes)..."
    flux bootstrap github \
        --owner=$GITHUB_USER \
        --repo=$GITHUB_REPO \
        --branch=main \
        --path=clusters/raspberry-pi-homelab \
        --personal \
        --skip-secret-creation 2>&1 | tail -20
    
    print_success "Flux bootstrap completed"
}

# Wait for components
wait_for_components() {
    print_header "Waiting for Flux Components"
    
    print_info "Waiting for flux-system pods to be ready (this may take a few minutes)..."
    kubectl rollout status deployment/source-controller -n flux-system --timeout=5m || print_warning "source-controller not ready"
    kubectl rollout status deployment/kustomize-controller -n flux-system --timeout=5m || print_warning "kustomize-controller not ready"
    kubectl rollout status deployment/helm-controller -n flux-system --timeout=5m || print_warning "helm-controller not ready"
    kubectl rollout status deployment/notification-controller -n flux-system --timeout=5m || print_warning "notification-controller not ready"
    
    print_success "Flux components ready"
}

# Verify installation
verify_installation() {
    print_header "Verifying Installation"
    
    print_info "Running Flux checks..."
    flux check --post || print_warning "Some checks failed"
    
    print_info "Checking Flux status..."
    flux status
    
    print_info "Listing Flux resources..."
    print_info "\nGitRepositories:"
    flux get sources git --all-namespaces || print_info "No GitRepositories yet"
    
    print_info "\nKustomizations:"
    flux get kustomizations --all-namespaces || print_info "No Kustomizations yet"
    
    print_info "\nFlux System Pods:"
    kubectl get pods -n flux-system
}

# Display next steps
next_steps() {
    print_header "Next Steps"
    
    cat << EOF
${GREEN}Flux CD has been successfully bootstrapped!${NC}

${BLUE}1. Verify Components:${NC}
   flux check
   flux status

${BLUE}2. Monitor Logs:${NC}
   flux logs --follow

${BLUE}3. Add Applications:${NC}
   - Create GitRepository sources
   - Create Kustomization resources
   - See docs/adding-new-app.md for examples

${BLUE}4. Common Commands:${NC}
   flux get sources git              # List Git sources
   flux get kustomizations           # List Kustomizations
   flux reconcile source git <name>  # Force reconcile
   flux suspend kustomization <name> # Pause syncing
   flux resume kustomization <name>  # Resume syncing

${BLUE}5. Documentation:${NC}
   - Bootstrap: docs/bootstrap.md
   - Migration: docs/migration-guide.md
   - Adding Apps: docs/adding-new-app.md
   - Troubleshooting: docs/troubleshooting.md

${BLUE}6. Important URLs:${NC}
   - Flux Docs: https://fluxcd.io/docs/
   - GitHub Repo: https://github.com/$GITHUB_USER/$GITHUB_REPO

EOF
}

# Main execution
main() {
    print_header "Flux CD Bootstrap"
    print_info "Starting Flux CD installation..."
    echo ""
    
    check_prerequisites
    echo ""
    
    run_preflightchecks
    echo ""
    
    print_info "Ready to install Flux. Continue? (y/n)"
    read -r confirm
    if [[ $confirm != "y" ]]; then
        print_warning "Installation cancelled"
        exit 0
    fi
    echo ""
    
    install_flux
    echo ""
    
    wait_for_components
    echo ""
    
    verify_installation
    echo ""
    
    next_steps
    echo ""
    
    print_success "Flux CD bootstrap completed successfully!"
}

# Run main function
main "$@"
