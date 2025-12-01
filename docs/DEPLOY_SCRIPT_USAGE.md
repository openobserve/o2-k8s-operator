
## Main Deployment Script (deploy.sh)

The `deploy.sh` script handles the complete lifecycle of operator management.

### Usage
```bash
./deploy.sh [OPTIONS]
```

### Options
- `--uninstall` - Uninstall the operator and all resources
- `--namespace <name>` - Target namespace (default: o2operator)
- `--image <repo>` - Custom image repository
- `--tag <tag>` - Custom image tag (default: latest)
- `--skip-certs` - Skip certificate generation (use existing)
- `--dry-run` - Preview changes without applying them
- `-h, --help` - Show help message

### Examples
```bash
# Basic installation
./deploy.sh

# Preview changes without applying (dry-run)
./deploy.sh --dry-run

# Install with custom image
./deploy.sh --image public.ecr.aws/zinclabs/o2operator --tag v1.0.0

# Uninstall operator (handles finalizers automatically)
./deploy.sh --uninstall

# Skip certificate generation (use existing certificates)
./deploy.sh --skip-certs
```

## Kubernetes Manifests

### Core Manifests (`manifests/`)

1. **00-namespace.yaml** - Creates the `o2operator` namespace
2. **CRD Files** - Custom Resource Definitions:
   - `01-o2configs.crd.yaml` - OpenObserveConfig for connection settings
   - `01-o2alerts.crd.yaml` - OpenObserveAlert for alert definitions
   - `01-o2pipelines.crd.yaml` - OpenObservePipeline for data pipeline configurations
3. **02-rbac.yaml** - Sets up RBAC:
   - ServiceAccount for the operator
   - ClusterRole with required permissions
   - ClusterRoleBinding
   - Leader election Role and RoleBinding
4. **03-deployment.yaml** - Contains:
   - Operator Deployment
   - Metrics Service (port 8080)
   - Webhook Service (port 443)
5. **04-webhook.yaml** - ValidatingWebhookConfiguration for resource validation

## Environment Configuration

### OpenObserve Configuration (`configs/`)

The `configs/` directory contains environment-specific configurations:

- **dev/o2dev-config.yaml** - Development environment configuration
- **test/o2test-config.yaml** - Test environment configuration
- **prod/o2prod-config.yaml** - Production environment configuration

Each configuration file contains:
- Secret definition for OpenObserve credentials
- OpenObserveConfig resource definition

**Important**: Edit the appropriate configuration file before applying to add your actual:
- OpenObserve endpoint URL
- Username and password
- Organization name

## Sample Resources

### Alert Samples (`samples/alerts/`)

11 example alert configurations demonstrating various use cases:
- **alert9-minimal.template.yaml** - Minimal configuration example
- **alert1-full.template.yaml** - Full-featured alert with all options
- **alert2-simple-log.template.yaml** - Basic log monitoring
- **alert3-sql.template.yaml** - SQL query-based alerts
- **alert4-promql.template.yaml** - PromQL metrics alerts
- **alert5-realtime.template.yaml** - Real-time alerting
- **alert6-deduplication.template.yaml** - Alert deduplication
- **alert7-multi-time-range.template.yaml** - Multiple time ranges
- **alert8-traces.template.yaml** - Distributed tracing alerts
- **alert-aggregation-example.yaml** - Aggregation examples
- **alert.sample.yaml** - General sample alert

### Pipeline Samples (`samples/pipelines/`)

5 pipeline configuration examples:
- **pipeline.sample.yaml** - General sample pipeline configuration
- **srctodest.yaml** - Simple source to destination pipeline
- **srctodest-two-branches.yaml** - Multi-branch pipeline with conditions
- **querysrctodest-sql.yaml** - SQL query-based data transformation
- **querysrctodest-promql.yaml** - PromQL query-based pipeline
