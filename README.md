# construct-x Edge Kubernetes Deployment

This repository contains an umbrella Helm chart for deploying construct-x edge components on Kubernetes. The deployment includes two main components:

1. **EDC (Eclipse Dataspace Connector)** - A connector for secure data exchange
2. **Weather Application** - A sample weather application that communicates through the EDC

## 🏗️ Architecture

The construct-x edge deployment demonstrates a simple edge computing scenario where a weather application retrieves and shares data through the Eclipse Dataspace Connector (EDC). This setup showcases secure data exchange patterns in edge environments.

```
┌─────────────────┐    ┌─────────────────┐
│   Weather App   │◄──►│       EDC       │
│   (nginx)       │    │   (nginx)       │
└─────────────────┘    └─────────────────┘
```

## 📁 Repository Structure

```
construct-x-edge-k8s/
├── Chart.yaml                    # Main umbrella chart definition
├── values.yaml                   # Default configuration values
├── templates/                    # Umbrella chart templates
│   ├── _helpers.tpl              # Helper templates
│   ├── NOTES.txt                 # Post-installation notes
│   └── ingress.yaml              # Ingress configuration
├── charts/                       # Subcharts directory
│   ├── edc/                      # EDC subchart
│   │   ├── Chart.yaml            # EDC chart definition
│   │   ├── values.yaml           # EDC default values
│   │   └── templates/            # EDC Kubernetes templates
│   │       ├── _helpers.tpl      # EDC helper templates
│   │       ├── deployment.yaml   # EDC deployment
│   │       └── service.yaml      # EDC service
│   └── weather/                  # Weather app subchart
│       ├── Chart.yaml            # Weather chart definition
│       ├── values.yaml           # Weather default values
│       └── templates/            # Weather Kubernetes templates
│           ├── _helpers.tpl      # Weather helper templates
│           ├── deployment.yaml   # Weather deployment
│           └── service.yaml      # Weather service
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.x
- kubectl configured to access your cluster
- Pre-existing namespace `edc` (or your chosen namespace)

### Creating the Target Namespace

```bash
kubectl create namespace edc
```

### Installation

#### Recommended: Using install.sh (Automated)

1. **Clone this repository:**

   ```bash
   git clone https://github.com/your-org/construct-x-edge-k8s.git
   cd construct-x-edge-k8s
   ```

2. **Run the installation script:**

   ```bash
   # Quick installation (uses "edc" namespace)
   ./install.sh

   # Or with custom options
   ./install.sh -n my-namespace -f custom-values.yaml
   ```

   The script automatically handles:

   - ✅ Chart dependency updates
   - ⚠️ Secret creation (commented out - uncomment when ready)
   - ✅ Chart validation and installation
   - ✅ Post-installation verification

#### Manual Installation

1. **Clone this repository:**

   ```bash
   git clone https://github.com/your-org/construct-x-edge-k8s.git
   cd construct-x-edge-k8s
   ```

2. **Update dependencies and install:**

   ```bash
   # Update dependencies
   helm dependency update

   # Install the chart
   helm install construct-x-edge . --namespace edc
   ```

3. **Create required secrets manually:**

   ```bash
   # EDC configuration secret
   kubectl create secret generic edc-config \
     --namespace=edc \
     --from-literal=api-key="your-api-key" \
     --from-literal=datasource-url="jdbc:postgresql://postgres:5432/edc"

   # Weather service secret
   kubectl create secret generic weather-config \
     --namespace=edc \
     --from-literal=api-key="your-weather-api-key"
   ```

### Verification

```bash
# Check deployment status
kubectl get pods -n edc
kubectl get services -n edc

# Check Helm release
helm status construct-x-edge -n edc
```

### Configuration

The chart can be configured through the `values.yaml` file or by passing values during installation:

```bash
helm install construct-x-edge . \
  --namespace construct-x-edge \
  --create-namespace \
  --set edc.enabled=true \
  --set weather.enabled=true \
  --set ingress.enabled=true
```

## ⚙️ Configuration Options

| Parameter               | Description                     | Default               |
| ----------------------- | ------------------------------- | --------------------- |
| `nginx-ingress.enabled` | Enable nginx ingress controller | `false`               |
| `edc.enabled`           | Enable EDC component            | `true`                |
| `weather.enabled`       | Enable weather component        | `true`                |
| `ingress.enabled`       | Enable ingress rules            | `false`               |
| `ingress.host`          | Hostname for ingress            | `construct-x.eecc.de` |

## 🔧 Advanced Usage

### Enabling Ingress

The setup assumes you have a reverse proxy in front of your cluster that handles SSL termination and redirects HTTP to HTTPS. You can either use an existing ingress controller or deploy the nginx ingress controller included in this chart.

#### Option 1: With included nginx ingress controller

```bash
# Install with nginx ingress controller and ingress rules
helm dependency update
helm install construct-x-edge . \
  --set nginx-ingress.enabled=true \
  --set ingress.enabled=true \
  --set ingress.host=construct-x.eecc.de \
  --namespace construct-x-edge \
  --create-namespace
```

#### Option 2: Using existing ingress controller

```bash
# Enable only ingress rules (assumes you have an ingress controller)
helm install construct-x-edge . \
  --set ingress.enabled=true \
  --set ingress.host=construct-x.eecc.de \
  --namespace construct-x-edge \
  --create-namespace
```

This creates ingress rules for:

- `https://construct-x.eecc.de/edc` → EDC service
- `https://construct-x.eecc.de/weather` → Weather service

Your reverse proxy handles:

- SSL/TLS termination
- HTTP → HTTPS redirect
- Certificate management

### Traffic Flow

```
User (HTTPS) → Reverse Proxy → Kubernetes Ingress (HTTP:80) → Services (HTTP:80)
```

1. **User** accesses `https://construct-x.eecc.de/edc`
2. **Reverse Proxy** terminates SSL and forwards to cluster on port 80
3. **Kubernetes Ingress** routes `/edc` → EDC service
4. **EDC Service** serves the nginx container

### Scaling Components

To scale the components:

```bash
helm upgrade construct-x-edge . \
  --set edc.replicaCount=3 \
  --set weather.replicaCount=2 \
  --namespace construct-x-edge
```

### Disabling Components

To disable specific components:

```bash
helm install construct-x-edge . \
  --set edc.enabled=true \
  --set weather.enabled=false \
  --namespace construct-x-edge
```

## 🔍 Monitoring and Debugging

### Check Pod Status

```bash
kubectl get pods -n construct-x-edge
kubectl describe pod <pod-name> -n construct-x-edge
```

### View Logs

```bash
kubectl logs -f deployment/construct-x-edge-edc -n construct-x-edge
kubectl logs -f deployment/construct-x-edge-weather -n construct-x-edge
```

### Access Services

Port-forward to access services locally:

```bash
# Access EDC
kubectl port-forward service/construct-x-edge-edc 8080:80 -n construct-x-edge

# Access Weather App
kubectl port-forward service/construct-x-edge-weather 8081:80 -n construct-x-edge
```

## 📖 Documentation

### Comprehensive Deployment Guide

For detailed deployment instructions, secrets management, and troubleshooting, see:

📋 **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Complete deployment guide covering:

- Secrets and dependencies management
- Advanced installation options
- Production deployment considerations
- Troubleshooting and maintenance procedures

### Installation Script Features

The `install.sh` script provides:

| Feature                   | Description                                     |
| ------------------------- | ----------------------------------------------- |
| **Dependency Management** | Automatically handles Chart.yaml dependencies   |
| **Secret Creation**       | Template for Kubernetes secrets (commented out) |
| **Validation**            | Pre and post-installation verification          |
| **Atomic Operations**     | Rollback on failure                             |
| **Flexible Options**      | Custom namespace, values files, dry-run mode    |

```bash
# See all available options
./install.sh --help
```

## 🗑️ Uninstalling

### Recommended: Using uninstall.sh (Automated)

```bash
# Basic uninstall (preserves secrets and namespace)
./uninstall.sh

# Uninstall and remove secrets
./uninstall.sh --remove-secrets

# Complete removal including namespace (DESTRUCTIVE)
./uninstall.sh --remove-namespace --force

# Uninstall from different namespace
./uninstall.sh -n my-namespace --remove-secrets

# See what would be removed (dry run)
./uninstall.sh --dry-run
```

The uninstall script provides:

- ✅ **Safe removal** with confirmation prompts
- ✅ **Selective cleanup** (release, secrets, namespace)
- ✅ **Verification** of complete removal
- ✅ **Dry run mode** to preview changes
- ✅ **Detailed logging** and error handling

### Manual Uninstallation

```bash
# Using Helm
helm uninstall construct-x-edge --namespace edc

# Remove secrets (optional)
kubectl delete secret edc-config weather-config tls-construct-x -n edc

# Remove namespace (optional - will remove all resources)
kubectl delete namespace edc
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🔗 Related Projects

- [Eclipse Dataspace Connector](https://github.com/eclipse-edc/Connector)
- [construct-x Project](https://github.com/your-org/construct-x)

## 📞 Support

For support and questions:

- Create an issue in this repository
- Contact the construct-x team at team@construct-x.org
- Check the [construct-x documentation](https://docs.construct-x.org)

---

**Note:** This is a demonstration setup using simple nginx containers. In a production environment, you would replace these with actual EDC and weather application images.
