#!/bin/bash

# uninstall.sh - Construct-X Edge Kubernetes Uninstallation Script
#
# Purpose: Safely remove the umbrella chart from the target namespace with
# comprehensive cleanup of resources, secrets, and dependencies.
#
# This script handles:
# - Helm release removal with validation
# - Optional secret cleanup
# - Resource verification and cleanup
# - Pre-uninstall safety checks
# - Post-uninstall verification

set -euo pipefail

# Configuration
NAMESPACE="edc"
CHART_NAME="construct-x-edge"
RELEASE_NAME="construct-x-edge"

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

# Function to verify namespace and release exist
verify_targets() {
    log_info "Verifying targets for uninstallation..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' does not exist - nothing to uninstall"
        return 1
    fi
    
    # Check if release exists
    if ! helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        log_warning "Helm release '$RELEASE_NAME' does not exist in namespace '$NAMESPACE'"
        return 1
    fi
    
    log_success "Found release '$RELEASE_NAME' in namespace '$NAMESPACE'"
    return 0
}

# Function to show what will be removed
show_removal_plan() {
    log_info "Uninstallation plan for release '$RELEASE_NAME' in namespace '$NAMESPACE':"
    
    echo ""
    echo "📋 Helm Release Information:"
    helm list -n "$NAMESPACE" | grep "^$RELEASE_NAME" || echo "Release not found"
    
    echo ""
    echo "🏗️  Resources to be removed:"
    kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" 2>/dev/null || echo "No labeled resources found"
    
    echo ""
    echo "🔐 Secrets that can be removed (if --remove-secrets is used):"
    kubectl get secrets -n "$NAMESPACE" 2>/dev/null | grep -E "(edc-config|weather-config|tls-construct-x)" || echo "No managed secrets found"
    
    echo ""
}

# Function to remove secrets
remove_secrets() {
    log_info "Removing managed secrets..."
    
    # List of secrets to remove
    SECRETS=("edc-config" "weather-config" "tls-construct-x")
    
    for secret in "${SECRETS[@]}"; do
        if kubectl get secret "$secret" -n "$NAMESPACE" &> /dev/null; then
            log_info "Removing secret '$secret'..."
            kubectl delete secret "$secret" -n "$NAMESPACE"
            log_success "Secret '$secret' removed"
        else
            log_warning "Secret '$secret' not found"
        fi
    done
}

# Function to remove helm release
remove_release() {
    log_info "Removing Helm release '$RELEASE_NAME'..."
    
    # Check if release exists before attempting removal
    if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        helm uninstall "$RELEASE_NAME" --namespace="$NAMESPACE" --wait --timeout=10m
        log_success "Helm release '$RELEASE_NAME' removed successfully"
    else
        log_warning "Release '$RELEASE_NAME' not found, skipping"
    fi
}

# Function to clean up remaining resources
cleanup_resources() {
    log_info "Cleaning up any remaining resources..."
    
    # Remove any remaining resources with the release label
    local remaining_resources
    remaining_resources=$(kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" --no-headers 2>/dev/null | wc -l)
    
    if [[ $remaining_resources -gt 0 ]]; then
        log_warning "Found $remaining_resources remaining resources, attempting cleanup..."
        kubectl delete all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" --timeout=300s || true
        
        # Wait a moment and check again
        sleep 5
        remaining_resources=$(kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" --no-headers 2>/dev/null | wc -l)
        
        if [[ $remaining_resources -gt 0 ]]; then
            log_warning "Some resources may still exist. Manual cleanup may be required:"
            kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" 2>/dev/null || true
        else
            log_success "All labeled resources cleaned up"
        fi
    else
        log_success "No remaining resources found"
    fi
}

# Function to verify uninstallation
verify_uninstallation() {
    log_info "Verifying uninstallation..."
    
    # Check if release is gone
    if helm list -n "$NAMESPACE" | grep -q "^$RELEASE_NAME"; then
        log_error "Release '$RELEASE_NAME' still exists after uninstallation"
        return 1
    fi
    
    # Check for remaining resources
    local remaining_resources
    remaining_resources=$(kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" --no-headers 2>/dev/null | wc -l)
    
    if [[ $remaining_resources -gt 0 ]]; then
        log_warning "Some resources with release labels still exist"
        kubectl get all -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" 2>/dev/null || true
        return 1
    fi
    
    log_success "Uninstallation verification completed successfully"
    return 0
}

# Function to show post-uninstall information
show_cleanup_info() {
    log_info "Post-uninstallation information:"
    
    echo ""
    echo "✅ Uninstallation Summary:"
    echo "   - Helm release '$RELEASE_NAME' removed from namespace '$NAMESPACE'"
    
    if [[ "$REMOVE_SECRETS" == "true" ]]; then
        echo "   - Managed secrets removed"
    else
        echo "   - Secrets preserved (use --remove-secrets to remove them)"
    fi
    
    if [[ "$REMOVE_NAMESPACE" == "true" ]]; then
        echo "   - Namespace '$NAMESPACE' removed"
    else
        echo "   - Namespace '$NAMESPACE' preserved"
    fi
    
    echo ""
    echo "📝 Remaining Resources in Namespace '$NAMESPACE':"
    kubectl get all -n "$NAMESPACE" 2>/dev/null || echo "   No resources found or namespace removed"
    
    echo ""
    echo "🔐 Remaining Secrets in Namespace '$NAMESPACE':"
    kubectl get secrets -n "$NAMESPACE" 2>/dev/null || echo "   No secrets found or namespace removed"
    
    echo ""
    if [[ "$REMOVE_NAMESPACE" == "false" ]]; then
        echo "💡 Next Steps:"
        echo "   1. To remove remaining secrets:"
        echo "      kubectl delete secret edc-config weather-config tls-construct-x -n $NAMESPACE"
        echo ""
        echo "   2. To remove the namespace entirely:"
        echo "      kubectl delete namespace $NAMESPACE"
        echo ""
        echo "   3. To reinstall:"
        echo "      ./install.sh -n $NAMESPACE"
    fi
}

# Function to remove namespace
remove_namespace() {
    log_info "Removing namespace '$NAMESPACE'..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "This will remove ALL resources in namespace '$NAMESPACE'"
        kubectl delete namespace "$NAMESPACE" --timeout=300s
        log_success "Namespace '$NAMESPACE' removed"
    else
        log_warning "Namespace '$NAMESPACE' not found"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace         Target namespace (default: edc)"
    echo "  -r, --release-name      Helm release name (default: construct-x-edge)"
    echo "  --remove-secrets        Remove managed secrets"
    echo "  --remove-namespace      Remove the entire namespace (DESTRUCTIVE)"
    echo "  --force                 Skip confirmation prompts"
    echo "  --dry-run              Show what would be removed without doing it"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Basic uninstall"
    echo "  $0 --remove-secrets                  # Uninstall and remove secrets"
    echo "  $0 --remove-namespace --force        # Remove everything including namespace"
    echo "  $0 -n my-namespace                   # Uninstall from different namespace"
    echo "  $0 --dry-run                        # Show removal plan"
    echo ""
    echo "⚠️  WARNING: --remove-namespace will delete ALL resources in the namespace!"
}

# Function to confirm destructive operations
confirm_operation() {
    local operation="$1"
    
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo ""
    log_warning "You are about to: $operation"
    read -p "Are you sure? (yes/no): " -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        return 0
    else
        log_info "Operation cancelled by user"
        exit 0
    fi
}

# Parse command line arguments
REMOVE_SECRETS=false
REMOVE_NAMESPACE=false
FORCE=false
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
        --remove-secrets)
            REMOVE_SECRETS=true
            shift
            ;;
        --remove-namespace)
            REMOVE_NAMESPACE=true
            shift
            ;;
        --force)
            FORCE=true
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
    log_info "Starting Construct-X Edge uninstallation..."
    log_info "Target namespace: $NAMESPACE"
    log_info "Release name: $RELEASE_NAME"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "Running in DRY RUN mode - no changes will be made"
    fi
    
    # Pre-uninstall checks
    check_prerequisites
    
    if ! verify_targets; then
        log_info "Nothing to uninstall"
        exit 0
    fi
    
    # Show what will be removed
    show_removal_plan
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry run completed - no changes made"
        exit 0
    fi
    
    # Confirmation for destructive operations
    if [[ "$REMOVE_NAMESPACE" == "true" ]]; then
        confirm_operation "remove the ENTIRE namespace '$NAMESPACE' and ALL its resources"
    elif [[ "$REMOVE_SECRETS" == "true" ]]; then
        confirm_operation "remove the Helm release '$RELEASE_NAME' and managed secrets"
    else
        confirm_operation "remove the Helm release '$RELEASE_NAME' (secrets will be preserved)"
    fi
    
    # Perform uninstallation
    if [[ "$REMOVE_NAMESPACE" == "true" ]]; then
        # If removing namespace, no need to remove release separately
        remove_namespace
    else
        # Remove release first
        remove_release
        
        # Remove secrets if requested
        if [[ "$REMOVE_SECRETS" == "true" ]]; then
            remove_secrets
        fi
        
        # Clean up any remaining resources
        cleanup_resources
        
        # Verify uninstallation
        verify_uninstallation
    fi
    
    # Show final status
    show_cleanup_info
    
    log_success "Uninstallation process completed!"
}

# Run main function
main "$@"
