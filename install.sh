#!/bin/bash

# install.sh - Construct-X Edge Kubernetes Installation Script
#
# Purpose: Install the umbrella chart into the "edc" namespace with all dependencies,
# secrets, and required configurations.
#
# This script handles:
# - Helm chart dependencies (via Chart.yaml dependencies)
# - Kubernetes secrets creation
# - Namespace verification
# - Pre-installation validation
# - Post-installation verification

set -euo pipefail

# Configuration
NAMESPACE="edc"
CHART_NAME="construct-x-edge"
RELEASE_NAME="construct-x-edge"
CHART_PATH="."
VALUES_FILE="values.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check kubectl connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to verify namespace exists
verify_namespace() {
    log_info "Verifying namespace '$NAMESPACE' exists..."
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist. Please create it first:"
        log_error "  kubectl create namespace $NAMESPACE"
        exit 1
    fi
    
    log_success "Namespace '$NAMESPACE' exists"
}

# Function to create required secrets
create_secrets() {
    log_info "Secret creation is currently disabled - configure secrets manually or uncomment below"
    
    # TODO: Uncomment and customize the secret creation below when ready to use
    
    # # EDC secrets (example - adjust based on actual requirements)
    # if ! kubectl get secret edc-config -n "$NAMESPACE" &> /dev/null; then
    #     log_info "Creating EDC configuration secret..."
    #     kubectl create secret generic edc-config \
    #         --namespace="$NAMESPACE" \
    #         --from-literal=api-key="change-me-in-production" \
    #         --from-literal=datasource-url="jdbc:postgresql://postgres:5432/edc" \
    #         --from-literal=datasource-username="edc" \
    #         --from-literal=datasource-password="change-me-in-production" \
    #         --dry-run=client -o yaml | kubectl apply -f -
    #     log_success "EDC configuration secret created"
    # else
    #     log_warning "EDC configuration secret already exists"
    # fi
    
    # # Weather service secrets (example - adjust based on actual requirements)
    # if ! kubectl get secret weather-config -n "$NAMESPACE" &> /dev/null; then
    #     log_info "Creating Weather service configuration secret..."
    #     kubectl create secret generic weather-config \
    #         --namespace="$NAMESPACE" \
    #         --from-literal=api-key="change-me-weather-api-key" \
    #         --from-literal=database-url="postgresql://postgres:5432/weather" \
    #         --from-literal=database-username="weather" \
    #         --from-literal=database-password="change-me-in-production" \
    #         --dry-run=client -o yaml | kubectl apply -f -
    #     log_success "Weather service configuration secret created"
    # else
    #     log_warning "Weather service configuration secret already exists"
    # fi
    
    # # TLS secrets for ingress (if needed)
    # if ! kubectl get secret tls-construct-x -n "$NAMESPACE" &> /dev/null; then
    #     log_info "Creating TLS secret for ingress..."
    #     # Note: In production, use proper certificates
    #     kubectl create secret tls tls-construct-x \
    #         --namespace="$NAMESPACE" \
    #         --cert=/path/to/cert.pem \
    #         --key=/path/to/key.pem \
    #         --dry-run=client -o yaml | kubectl apply -f -
    #     log_warning "TLS secret created - ensure certificates are properly configured"
    # else
    #     log_warning "TLS secret already exists"
    # fi
}

# Function to update Helm dependencies
update_dependencies() {
    log_info "Updating Helm chart dependencies..."
    
    # Update dependencies as defined in Chart.yaml
    helm dependency update "$CHART_PATH"
    
    log_success "Helm dependencies updated"
}

# Function to validate chart
validate_chart() {
    log_info "Validating Helm chart..."
    
    # Lint the chart
    if ! helm lint "$CHART_PATH"; then
        log_error "Helm chart validation failed"
        exit 1
    fi
    
    # Test template rendering
    log_info "Testing template rendering..."
    helm template "$RELEASE_NAME" "$CHART_PATH" \
        --namespace="$NAMESPACE" \
        --values="$VALUES_FILE" \
        --debug > /dev/null
    
    log_success "Chart validation passed"
}

# Function to install or upgrade the chart
install_chart() {
    log_info "Installing/upgrading Helm chart..."
    
    # Check if release already exists
    if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        log_info "Release '$RELEASE_NAME' already exists, upgrading..."
        helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
            --namespace="$NAMESPACE" \
            --values="$VALUES_FILE" \
            --wait \
            --timeout=10m \
            --atomic
        log_success "Chart upgraded successfully"
    else
        log_info "Installing new release '$RELEASE_NAME'..."
        helm install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace="$NAMESPACE" \
            --values="$VALUES_FILE" \
            --wait \
            --timeout=10m \
            --atomic
        log_success "Chart installed successfully"
    fi
}

# Function to verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check release status
    if ! helm status "$RELEASE_NAME" -n "$NAMESPACE" | grep -q "STATUS: deployed"; then
        log_error "Release is not in deployed state"
        exit 1
    fi
    
    # Wait for pods to be ready
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod \
        --selector="app.kubernetes.io/instance=$RELEASE_NAME" \
        --namespace="$NAMESPACE" \
        --timeout=300s || true
    
    # Show deployment status
    log_info "Deployment status:"
    kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
    
    log_success "Installation verification completed"
}

# Function to show post-installation information
show_info() {
    log_info "Post-installation information:"
    
    echo ""
    echo "📋 Release Information:"
    helm list -n "$NAMESPACE"
    
    echo ""
    echo "🏗️  Deployed Resources:"
    kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
    
    echo ""
    echo "🔐 Secrets:"
    kubectl get secrets -n "$NAMESPACE" | grep -E "(edc-config|weather-config|tls-construct-x)" || echo "No managed secrets found"
    
    echo ""
    echo "📝 Next Steps:"
    echo "1. Update secrets with production values:"
    echo "   kubectl edit secret edc-config -n $NAMESPACE"
    echo "   kubectl edit secret weather-config -n $NAMESPACE"
    echo ""
    echo "2. Configure ingress if enabled:"
    echo "   kubectl get ingress -n $NAMESPACE"
    echo ""
    echo "3. Check logs:"
    echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/instance=$RELEASE_NAME"
    echo ""
    echo "4. Access services:"
    echo "   kubectl port-forward -n $NAMESPACE svc/<service-name> <local-port>:<service-port>"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace         Target namespace (default: edc)"
    echo "  -r, --release-name      Helm release name (default: construct-x-edge)"
    echo "  -f, --values-file       Values file path (default: values.yaml)"
    echo "  --skip-secrets          Skip secret creation"
    echo "  --skip-dependencies     Skip dependency update"
    echo "  --dry-run              Perform a dry run without installing"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Install with defaults"
    echo "  $0 -n my-namespace                   # Install in different namespace"
    echo "  $0 -f custom-values.yaml            # Use custom values file"
    echo "  $0 --dry-run                        # Dry run mode"
}

# Parse command line arguments
SKIP_SECRETS=false
SKIP_DEPENDENCIES=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release-name)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        --skip-secrets)
            SKIP_SECRETS=true
            shift
            ;;
        --skip-dependencies)
            SKIP_DEPENDENCIES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting Construct-X Edge installation..."
    log_info "Target namespace: $NAMESPACE"
    log_info "Release name: $RELEASE_NAME"
    log_info "Values file: $VALUES_FILE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
    fi
    
    # Pre-installation checks
    check_prerequisites
    verify_namespace
    
    # Update dependencies (unless skipped)
    if [[ "$SKIP_DEPENDENCIES" == "false" ]]; then
        update_dependencies
    else
        log_warning "Skipping dependency update"
    fi
    
    # Validate chart
    validate_chart
    
    # Create secrets (unless skipped or dry run)
    if [[ "$SKIP_SECRETS" == "false" && "$DRY_RUN" == "false" ]]; then
        create_secrets
    else
        log_warning "Skipping secret creation"
    fi
    
    # Install chart (unless dry run)
    if [[ "$DRY_RUN" == "false" ]]; then
        install_chart
        verify_installation
        show_info
    else
        log_info "Dry run completed - chart would be installed with current configuration"
        helm template "$RELEASE_NAME" "$CHART_PATH" \
            --namespace="$NAMESPACE" \
            --values="$VALUES_FILE" \
            --debug
    fi
    
    log_success "Installation process completed!"
}

# Run main function
main "$@"
