# Deployment Guide - Construct-X Edge

This document describes the deployment process for the Construct-X Edge umbrella chart, including secrets management and dependency handling.

## Overview

The `install.sh` script provides a comprehensive installation process that handles:

- ✅ **Chart Dependencies**: Automatically managed via `Chart.yaml` dependencies
- ✅ **Kubernetes Secrets**: Created for secure configuration management
- ✅ **Namespace Management**: Assumes pre-existing "edc" namespace
- ✅ **Validation**: Pre and post-installation verification
- ✅ **Rollback Support**: Atomic installations with automatic rollback on failure

## Prerequisites

1. **Kubernetes Cluster**: Access to a running Kubernetes cluster
2. **kubectl**: Configured to access your target cluster
3. **Helm 3.x**: Installed and available in PATH
4. **Namespace**: The "edc" namespace must exist before installation

### Creating the Target Namespace

```bash
kubectl create namespace edc
```

## Dependencies Management

### Chart.yaml Dependencies

The umbrella chart manages dependencies through `Chart.yaml`:

```yaml
dependencies:
  - name: ingress-nginx
    version: "4.8.3"
    repository: "https://kubernetes.github.io/ingress-nginx"
    condition: nginx-ingress.enabled
  - name: edc
    version: "0.1.0"
    repository: "file://./charts/edc"
    condition: edc.enabled
  - name: weather
    version: "0.1.0"
    repository: "file://./charts/weather"
    condition: weather.enabled
```

**Automatic Handling**: The `install.sh` script automatically runs `helm dependency update` to:

- Download external dependencies (like ingress-nginx)
- Package local subcharts
- Ensure all dependencies are available for installation

### External Dependencies

Some dependencies cannot be managed through Chart.yaml and are handled by `install.sh`:

1. **Kubernetes Secrets**: Created programmatically
2. **Custom Resources**: Applied before chart installation
3. **Namespace Setup**: Verified before installation
4. **TLS Certificates**: Created with placeholder values

## Secrets Management

### Secret Creation Templates

⚠️ **Note**: Secret creation is commented out by default in the installation script. Uncomment and customize the secret creation section in `install.sh` when ready to use.

The installation script includes templates for the following secrets:

#### EDC Configuration Secret (`edc-config`)

```bash
kubectl create secret generic edc-config \
  --namespace=edc \
  --from-literal=api-key="change-me-in-production" \
  --from-literal=datasource-url="jdbc:postgresql://postgres:5432/edc" \
  --from-literal=datasource-username="edc" \
  --from-literal=datasource-password="change-me-in-production"
```

#### Weather Service Secret (`weather-config`)

```bash
kubectl create secret generic weather-config \
  --namespace=edc \
  --from-literal=api-key="change-me-weather-api-key" \
  --from-literal=database-url="postgresql://postgres:5432/weather" \
  --from-literal=database-username="weather" \
  --from-literal=database-password="change-me-in-production"
```

#### TLS Secret (`tls-construct-x`)

```bash
kubectl create secret tls tls-construct-x \
  --namespace=edc \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem
```

### Production Secret Management

⚠️ **Security Warning**: The default secrets contain placeholder values that MUST be updated for production use.

#### Recommended Approach:

1. **External Secret Management**: Use tools like:

   - [External Secrets Operator](https://external-secrets.io/)
   - [Vault](https://www.vaultproject.io/)
   - [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/)
   - [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)

2. **Manual Secret Updates**:

   ```bash
   # Update EDC secrets
   kubectl edit secret edc-config -n edc

   # Update Weather secrets
   kubectl edit secret weather-config -n edc

   # Update TLS certificates
   kubectl create secret tls tls-construct-x \
     --namespace=edc \
     --cert=production-cert.pem \
     --key=production-key.pem \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **Secret Rotation**: Implement regular secret rotation procedures

## Installation Process

### Quick Installation

```bash
./install.sh
```

### Advanced Installation Options

```bash
# Install with custom values file
./install.sh -f production-values.yaml

# Install in different namespace
./install.sh -n my-namespace

# Skip secret creation (if managing externally)
./install.sh --skip-secrets

# Dry run to see what would be installed
./install.sh --dry-run

# Full custom installation
./install.sh -n production -r construct-x-prod -f prod-values.yaml
```

### Installation Steps Breakdown

1. **Prerequisites Check**: Verify kubectl, helm, and cluster connectivity
2. **Namespace Verification**: Ensure target namespace exists
3. **Dependency Update**: Download and package all chart dependencies
4. **Chart Validation**: Lint and test template rendering
5. **Secret Creation**: Create required Kubernetes secrets
6. **Chart Installation**: Install or upgrade the Helm release
7. **Verification**: Wait for pods and verify deployment health
8. **Information Display**: Show deployment status and next steps

## Post-Installation

### Verification Commands

```bash
# Check release status
helm status construct-x-edge -n edc

# View all deployed resources
kubectl get all -n edc -l app.kubernetes.io/instance=construct-x-edge

# Check pod status
kubectl get pods -n edc

# View logs
kubectl logs -n edc -l app.kubernetes.io/instance=construct-x-edge --tail=100
```

### Service Access

```bash
# Port forward to access services locally
kubectl port-forward -n edc svc/edc-service 8080:80
kubectl port-forward -n edc svc/weather-service 8081:80

# Access via ingress (if enabled)
curl -H "Host: construct-x.eecc.de" http://<ingress-ip>/
```

## Troubleshooting

### Common Issues

1. **Namespace Not Found**

   ```bash
   kubectl create namespace edc
   ```

2. **Secret Already Exists**

   ```bash
   kubectl delete secret edc-config -n edc
   ./install.sh
   ```

3. **Dependency Update Fails**

   ```bash
   helm dependency update --debug
   ```

4. **Pod Not Starting**
   ```bash
   kubectl describe pod <pod-name> -n edc
   kubectl logs <pod-name> -n edc
   ```

### Rollback Procedures

```bash
# List release history
helm history construct-x-edge -n edc

# Rollback to previous version
helm rollback construct-x-edge -n edc

# Rollback to specific revision
helm rollback construct-x-edge 1 -n edc
```

## Uninstallation

### Automated Uninstallation with uninstall.sh

The `uninstall.sh` script provides comprehensive removal capabilities:

#### Basic Uninstallation

```bash
# Safe uninstall (preserves secrets and namespace)
./uninstall.sh

# Preview what would be removed
./uninstall.sh --dry-run
```

#### Advanced Uninstallation Options

```bash
# Remove release and secrets
./uninstall.sh --remove-secrets

# Complete removal (DESTRUCTIVE - removes entire namespace)
./uninstall.sh --remove-namespace --force

# Custom namespace
./uninstall.sh -n production --remove-secrets

# See all options
./uninstall.sh --help
```

#### Uninstall Script Features

| Feature                  | Description                                         |
| ------------------------ | --------------------------------------------------- |
| **Safety Checks**        | Verifies targets exist before removal               |
| **Confirmation Prompts** | Asks for confirmation before destructive operations |
| **Selective Removal**    | Choose what to remove (release, secrets, namespace) |
| **Dry Run Mode**         | Preview changes without making them                 |
| **Verification**         | Confirms complete removal                           |
| **Error Handling**       | Graceful handling of missing resources              |

#### Uninstallation Process

1. **Prerequisites Check**: Verify kubectl, helm, and cluster connectivity
2. **Target Verification**: Confirm release and namespace exist
3. **Removal Plan**: Display what will be removed
4. **User Confirmation**: Prompt for confirmation (unless --force)
5. **Resource Removal**: Remove Helm release and optionally secrets/namespace
6. **Cleanup**: Remove any remaining labeled resources
7. **Verification**: Confirm complete removal
8. **Summary**: Display post-uninstall status

### Manual Uninstallation

For manual control or debugging:

```bash
# Remove Helm release
helm uninstall construct-x-edge -n edc

# Remove specific secrets
kubectl delete secret edc-config -n edc
kubectl delete secret weather-config -n edc
kubectl delete secret tls-construct-x -n edc

# Remove remaining resources by label
kubectl delete all -l app.kubernetes.io/instance=construct-x-edge -n edc

# Remove namespace (removes everything)
kubectl delete namespace edc
```

## Security Considerations

1. **Secret Management**: Never commit secrets to version control
2. **Network Policies**: Implement proper network segmentation
3. **RBAC**: Use appropriate role-based access controls
4. **Image Security**: Scan container images for vulnerabilities
5. **TLS**: Always use proper certificates in production
6. **Updates**: Keep dependencies and base images updated

## Maintenance

### Regular Tasks

1. **Dependency Updates**: Check for chart dependency updates monthly
2. **Secret Rotation**: Rotate secrets according to security policy
3. **Health Monitoring**: Monitor deployment health and resource usage
4. **Backup**: Backup configurations and persistent data
5. **Updates**: Apply security updates and patches regularly

### Updating Dependencies

```bash
# Update Chart.yaml with new versions
vim Chart.yaml

# Update dependencies
helm dependency update

# Test changes
./install.sh --dry-run

# Deploy updates
./install.sh
```

## Advanced Configuration

For advanced configuration options, see:

- [values.yaml](./values.yaml) - Main configuration file
- [charts/edc/values.yaml](./charts/edc/values.yaml) - EDC-specific settings
- [charts/weather/values.yaml](./charts/weather/values.yaml) - Weather service settings
