# OpenObserve Kubernetes Operator

A Kubernetes operator that enables declarative management of OpenObserve Enterprise resources (alerts, pipelines) as native Kubernetes Custom Resources.

## Overview

The OpenObserve Operator allows you to manage OpenObserve configuration objects using Kubernetes CRDs, enabling GitOps workflows and infrastructure-as-code practices for your observability stack.

> [!IMPORTANT]
> This operator is designed to work with **OpenObserve Enterprise** only. It requires Enterprise API features that are not available in the open-source version.

**Note:** This operator manages OpenObserve configuration objects only. It does not install or manage the OpenObserve application itself.

## Features

- **Declarative Configuration**: Define alerts and pipelines as Kubernetes resources
- **GitOps Ready**: Version control and manage observability configurations
- **Multi-Instance Support**: Manage multiple OpenObserve instances from a single cluster
- **Status Reporting**: Real-time sync status and error reporting

## Supported Resources

- **OpenObserveConfig**: Connection configuration for OpenObserve instances
- **Alert**: OpenObserve alert definitions
- **Pipeline**: OpenObserve data pipeline definitions

## Quick Start

### Prerequisites

- Kubernetes 1.25+
- **OpenObserve Enterprise Instance**
- OpenObserve Enterprise API credentials

### Installation

### 1. Deploy the Operator

```bash
# Install the operator with default settings
./deploy.sh

# Or install with a custom image and tag
./deploy.sh --image myrepo/o2operator --tag v1.0.0
```

### 2. Configure OpenObserve Connection

Apply the appropriate configuration file from `configs/` based on your environment:

```bash
# For development environment
kubectl apply -f configs/dev/o2dev-config.yaml

# For test environment
kubectl apply -f configs/test/o2test-config.yaml

# For production environment
kubectl apply -f configs/prod/o2prod-config.yaml
```

**Note**: Edit the configuration files to add your actual OpenObserve credentials before applying.

### 3. Deploy Sample Resources

Use templates from the `samples/` directory:

**Important:** The sample files have different configRef requirements:
- Most samples reference `openobserve-main` in their `configRef`
- `alert9-minimal.template.yaml` references `openobserve-config` and uses `default` namespace

The provided configs create resources named:
- `openobserve-dev` (from configs/dev/o2dev-config.yaml)
- `openobserve-test` (from configs/test/o2test-config.yaml)
- `openobserve-prod` (from configs/prod/o2prod-config.yaml)

Before deploying samples, you need to either:
1. Create your own OpenObserveConfig with the name expected by the sample file, OR
2. Update the `configRef` name and namespace in the sample files to match your deployed config

```bash
# Deploy a minimal alert
kubectl apply -f samples/alerts/alert9-minimal.template.yaml

# Deploy a simple pipeline
kubectl apply -f samples/pipelines/srctodest.yaml
```


### Basic Usage

1. Create a Secret with OpenObserve credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: o2-credentials
  namespace: default
type: Opaque
stringData:
  token: "your-api-token"
```

2. Create an OpenObserveConfig:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveConfig
metadata:
  name: production
spec:
  endpoint: https://api.openobserve.ai
  organization: my-org
  credentialsSecretRef:
    name: o2-credentials
```

3. Create an Alert:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: Alert
metadata:
  name: high-error-rate
spec:
  configRef:
    name: production

  name: high-error-rate-alert
  streamName: default
  streamType: logs
  enabled: true

  queryCondition:
    type: custom
    sql: "SELECT COUNT(*) as count FROM default WHERE level='error'"
    aggregation:
      function: count
      having:
        column: count
        operator: GreaterThan
        value: 100

  duration: 5
  frequency: 1

  destinations:
    - slack-alerts
```

## Documentation

- [Product Requirements Document](PRD.md)
- [API Reference](docs/api.md) (coming soon)
- [Samples](samples/)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Manual Deployment](docs/MANUAL_DEPLOYMENT.md)
- [Deploy Script Usage](docs/DEPLOY_SCRIPT_USAGE.md)

## Security Notes

- Credentials are stored as Kubernetes Secrets
- Webhook uses auto-generated TLS certificates
- The operator requires cluster-wide permissions for CRD management
- TLS verification can be configured per OpenObserveConfig resource

## Development Status

**Current Status**: Pre-alpha / Planning

See [PRD.md](PRD.md) for detailed requirements and roadmap.

## License

TBD

## Complete Cleanup

The uninstall process (`./deploy.sh --uninstall`) will:
1. Remove finalizers from all custom resources
2. Delete all OpenObserve custom resources
3. Remove the operator deployment and services
4. Delete RBAC resources
5. Remove CRDs
6. Delete the operator namespace

## Additional Resources

- [OpenObserve Enterprise Documentation](https://openobserve.ai/docs/)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [Custom Resource Definitions Guide](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Reporting Issues

If you encounter any bugs or have feature requests, please [open an issue](https://github.com/openobserve/o2-k8s-operator/issues) on our GitHub repository.
