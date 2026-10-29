# OpenObserve Kubernetes Operator

A Kubernetes operator that enables declarative management of resources of OpenObserve Enterprise and OpenObserve Cloud (alerts, pipelines, functions) as native Kubernetes Custom Resources.

## Overview

The OpenObserve Operator allows you to manage OpenObserve configuration objects using Kubernetes CRDs, enabling GitOps workflows and infrastructure-as-code practices for your observability stack.

> [!IMPORTANT]
> This operator works with **OpenObserve Enterprise** and **OpenObserve Cloud** only. It requires API features that are not available in the open-source version. See [Supported OpenObserve editions](#supported-openobserve-editions).

**Note:** This operator manages OpenObserve configuration objects only. It does not install or manage the OpenObserve application itself.

## Features

- **Declarative Configuration**: Define alerts, pipelines, and functions as Kubernetes resources
- **GitOps Ready**: Version control and manage observability configurations
- **Multi-Instance Support**: Manage multiple OpenObserve Enterprise or Cloud instances from a single cluster
- **Status Reporting**: Real-time sync status and error reporting

## Supported Resources

- **OpenObserveConfig**: Connection configuration for OpenObserve Enterprise or Cloud instances
- **Alert**: OpenObserve alert definitions
- **AlertTemplate**: Templates for formatting alert notifications (HTTP or email)
- **Destination**: Alert and pipeline destination definitions (HTTP or email)
- **Pipeline**: OpenObserve data pipeline definitions
- **Function**: OpenObserve VRL transformation functions
- **Dashboard**: OpenObserve dashboard definitions with panels, queries, and visualizations
- **PrometheusRuleBinding**: Syncs existing prometheus-operator `PrometheusRule` objects into OpenObserve alerts, without modifying them

## Supported OpenObserve editions

| Edition | `build_type` | Supported |
|---------|--------------|-----------|
| OpenObserve Enterprise (self-hosted) | `enterprise` | Yes |
| OpenObserve Cloud | `cloud` | Yes |
| OpenObserve open source | `opensource` | No |

The operator reads `build_type` from the instance's `GET /config` endpoint whenever it validates an `OpenObserveConfig`: on create and update (at most once a minute), every 15 minutes while it is valid, and every 5 minutes while it is not. If the edition is not supported:

- the validating webhook rejects the `OpenObserveConfig` with `Please connect to OpenObserve Enterprise or Cloud` (when the instance cannot be reached at admission time the webhook only logs a warning and lets it through), and
- the config is marked `Ready=False`, and no resources that reference it (alerts, alert templates, destinations, pipelines, functions, dashboards, PrometheusRuleBindings) are synced.

### Connecting to OpenObserve Cloud

- **Endpoint:** `https://api.openobserve.ai`
- **Organization:** use the organization **identifier** (for example `2Ab3Cd4Ef5Gh6Ij7Kl8Mn9Op0Qr`). It is shown in the Cloud UI and returned by `GET /api/organizations`. The display name also resolves, but the identifier is unique and is what the API paths use.
- **Credentials:** Cloud uses SSO, so password login is not available. Create a service account in the organization and use its email and token with `key: token`.
- **Permissions:** the service account needs a role that grants access to the resources the operator manages (alerts, templates, destinations, functions, pipelines, dashboards and folders). A service account without a role can log in, but every API call returns `403 Unauthorized Access` and resources will fail to sync.

See [`configs/cloud-service-account-example.yaml`](configs/cloud-service-account-example.yaml) for a complete example.

## Quick Start

### Prerequisites

- Kubernetes 1.25+
- **OpenObserve Enterprise or OpenObserve Cloud** (see [Supported OpenObserve editions](#supported-openobserve-editions))
- OpenObserve API credentials (a service account is recommended)

### Installation

### 1. Deploy the Operator

```bash
# Install the operator with default settings
./deploy.sh

# Or install with a custom image and tag
./deploy.sh --image myrepo/o2operator --tag v1.0.0
```

### 2. Configure the OpenObserve Connection

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
- `samples/alerts/` - Alert configuration examples
- `samples/alerttemplates/` - Alert template examples for formatting notifications
- `samples/destinations/` - Destination examples for alerts and pipelines
- `samples/pipelines/` - Pipeline configuration examples
- `samples/functions/` - Function transformation examples
- `samples/dashboards/` - Dashboard configuration examples with panels and visualizations
- `samples/prometheusrules/` - PrometheusRuleBinding examples for syncing existing PrometheusRule objects

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

# Deploy a basic function
kubectl apply -f samples/functions/basic-function.yaml

# Deploy a dashboard
kubectl apply -f samples/dashboards/minimal-dashboard.yaml
```


### Basic Usage

1. Create a Secret with OpenObserve service account credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: o2-credentials
  namespace: default
type: Opaque
stringData:
  username: "service-account@example.com"   # Service account email
  token: "your-service-account-token"
```

2. Create an OpenObserveConfig:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: Config
metadata:
  name: production
spec:
  endpoint: https://api.openobserve.ai
  organization: my-org  # on OpenObserve Cloud, use the organization identifier
  credentialsSecretRef:
    name: o2-credentials
    key: token  # service account: username + token
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

4. Create an AlertTemplate:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: AlertTemplate
metadata:
  name: slack-webhook-template
spec:
  configRef:
    name: production

  name: slack-webhook-template
  title: "Alert: {alert_name}"
  body: |
    {
      "text": "🚨 *Alert Triggered*",
      "blocks": [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Alert:* {alert_name}\n*Stream:* {stream_name}\n*Severity:* {severity}\n*Time:* {triggered_at}"
          }
        }
      ]
    }
  type: http
  isDefault: false
```

5. Create a Destination:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: Destination
metadata:
  name: slack-alerts
spec:
  configRef:
    name: production

  name: slack-alerts-destination
  type: http
  url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
  method: post
  headers:
    Content-Type: application/json
  template: slack-webhook-template
  skipTlsVerify: false
```

6. Create a Function:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: Function
metadata:
  name: data-transformer
spec:
  configRef:
    name: production

  name: data-transformer-function
  function: |
    # VRL transformation function
    .processed_at = now()
    .environment = "production"
    if exists(.error) {
      .severity = "high"
    }
    .

  test:
    enabled: true
    input:
      - error: "Connection timeout"
        message: "Failed to connect"
    output:
      - error: "Connection timeout"
        message: "Failed to connect"
        processed_at: "2024-01-01T00:00:00Z"
        environment: "production"
        severity: "high"
```

## Admission webhooks

The operator registers a validating webhook for every resource kind (`manifests/04-webhook.yaml`, `failurePolicy: Fail`). Things to be aware of:

- **Apply order matters.** Resources are validated against OpenObserve when they are created or updated, so apply the `Config` (and its Secret) first, then alert templates, then destinations, then alerts and pipelines that use them. A resource whose dependency does not exist yet is rejected; re-apply it once the dependency has synced.
- **OpenObserve must be reachable.** Alert, alert template and destination requests are rejected while the referenced OpenObserve instance cannot be reached or rejects the credentials. Function requests are rejected when OpenObserve rejects the credentials or when `spec.test` is enabled and the test cannot run; if OpenObserve is only unreachable they are let through with a warning. Dashboard requests are rejected while the referenced `Config` is not `Ready`. Config and pipeline requests only log a warning when OpenObserve cannot be reached.
- **Configs in use cannot be deleted.** Deleting a `Config` is rejected while alerts or pipelines still reference it.
- **Realtime pipelines cannot be renamed.** Changing `spec.name` of a realtime pipeline that has already synced is rejected; delete the resource and create a new one with the new name.

## Documentation

- [Product Requirements Document](PRD.md)
- [API Reference](docs/api.md) (coming soon)
- [Samples](samples/)
  - [Alert Examples](samples/alerts/)
  - [Alert Template Examples](samples/alerttemplates/)
  - [Destination Examples](samples/destinations/)
  - [Pipeline Examples](samples/pipelines/)
  - [Function Examples](samples/functions/)
  - [PrometheusRule Support](samples/prometheusrules/)
  - [Function Template Reference](samples/functions/functions.template)
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

See [O2OPERATOR_FEATURES.md](docs/O2OPERATOR_FEATURES.md) for detailed features.

## License

TBD

## Complete Cleanup

The uninstall process (`./deploy.sh --uninstall`) will:
1. Remove finalizers from all custom resources
2. Delete all OpenObserve custom resources (alerts, alerttemplates, destinations, pipelines, functions)
3. Remove the operator deployment and services
4. Delete RBAC resources
5. Remove CRDs
6. Delete the operator namespace

## Additional Resources

- [OpenObserve Documentation](https://openobserve.ai/docs/)
- [Kubernetes Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [Custom Resource Definitions Guide](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Reporting Issues

If you encounter any bugs or have feature requests, please [open an issue](https://github.com/openobserve/o2-k8s-operator/issues) on our GitHub repository.
