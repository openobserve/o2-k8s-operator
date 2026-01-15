# OpenObserve Operator Kubernetes Manifests

This directory contains all the Kubernetes manifests required to deploy the OpenObserve Operator in your cluster.

## 📁 File Structure

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Creates the `o2operator` namespace for all operator resources |
| `01-o2*.crd.yaml` | Custom Resource Definitions (CRDs) for OpenObserve resources |
| `02-configmap.yaml` | Configuration settings for the operator |
| `02-rbac.yaml` | RBAC permissions (ServiceAccount, ClusterRole, ClusterRoleBinding) |
| `03-deployment.yaml` | Production-grade operator deployment with HA support |
| `04-webhook.yaml` | Webhook configurations for admission control |

## 📋 CRD Files

The operator manages 7 custom resource types:

- **`01-o2alerts.crd.yaml`**: Alert definitions for monitoring
- **`01-o2alerttemplates.crd.yaml`**: Reusable alert templates
- **`01-o2configs.crd.yaml`**: OpenObserve connection configurations
- **`01-o2dashboards.crd.yaml`**: Dashboard definitions with panels and visualizations
- **`01-o2destinations.crd.yaml`**: Notification destinations (Slack, email, PagerDuty)
- **`01-o2functions.crd.yaml`**: Data transformation functions
- **`01-o2pipelines.crd.yaml`**: Data pipeline definitions

## 🚀 Deployment Instructions

### Quick Install (All Resources)

Deploy all resources in the correct order:

```bash
# Apply all manifests
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-o2alerts.crd.yaml
kubectl apply -f 01-o2alerttemplates.crd.yaml
kubectl apply -f 01-o2configs.crd.yaml
kubectl apply -f 01-o2dashboards.crd.yaml
kubectl apply -f 01-o2destinations.crd.yaml
kubectl apply -f 01-o2functions.crd.yaml
kubectl apply -f 01-o2pipelines.crd.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 02-rbac.yaml
kubectl apply -f 03-deployment.yaml
kubectl apply -f 04-webhook.yaml
```

Or apply all at once:

```bash
kubectl apply -f .
```

### Step-by-Step Installation

1. **Create namespace:**
   ```bash
   kubectl apply -f 00-namespace.yaml
   ```

2. **Install CRDs:**
   ```bash
   kubectl apply -f 01-o2*.crd.yaml
   ```

3. **Configure operator settings:**
   ```bash
   kubectl apply -f 02-configmap.yaml
   ```

4. **Set up RBAC:**
   ```bash
   kubectl apply -f 02-rbac.yaml
   ```

5. **Deploy the operator:**
   ```bash
   kubectl apply -f 03-deployment.yaml
   ```

6. **Enable webhooks (optional but recommended):**
   ```bash
   kubectl apply -f 04-webhook.yaml
   ```

## ⚙️ Configuration

### ConfigMap Settings (`02-configmap.yaml`)

The ConfigMap controls operator behavior:

| Variable | Description | Default |
|----------|-------------|---------|
| `O2OPERATOR_LOG_LEVEL` | Logging level (debug, info, error) | info |
| `ALERT_CONTROLLER_CONCURRENCY` | Alert controller worker threads | 5 |
| `TEMPLATE_CONTROLLER_CONCURRENCY` | Template controller worker threads | 3 |
| `DESTINATION_CONTROLLER_CONCURRENCY` | Destination controller worker threads | 3 |
| `PIPELINE_CONTROLLER_CONCURRENCY` | Pipeline controller worker threads | 5 |
| `FUNCTION_CONTROLLER_CONCURRENCY` | Function controller worker threads | 3 |
| `CONFIG_CONTROLLER_CONCURRENCY` | Config controller worker threads | 2 |
| `DASHBOARD_CONTROLLER_CONCURRENCY` | Dashboard controller worker threads | 1 |
| `O2_HTTP_TIMEOUT` | HTTP client timeout | 30s |
| `O2_HTTP_RETRY_MAX` | Maximum retry attempts | 3 |
| `O2_HTTP_RETRY_WAIT` | Initial retry wait time | 1s |
| `O2_RATE_LIMIT` | Requests per second limit | 10 |
| `O2_RATE_BURST` | Burst capacity | 20 |

### Deployment Configuration (`03-deployment.yaml`)

The deployment includes:
- **High Availability**: 2 replicas with leader election enabled
- **Zero-downtime updates**: Rolling update strategy
- **Pod anti-affinity**: Spreads replicas across nodes
- **Resource limits**: CPU and memory constraints
- **Health checks**: Liveness and readiness probes
- **Webhook support**: Admission control enabled

## 🔐 Security Features

1. **RBAC**: Least privilege access with specific permissions per resource
2. **Webhooks**: Validation and mutation webhooks for resource integrity
3. **Service Account**: Dedicated service account with scoped permissions
4. **Network Policies**: Can be added for additional network isolation

## 📊 Monitoring

The operator exposes metrics on port 8080:
- Prometheus-compatible metrics at `/metrics`
- Health check at port 8081 `/healthz`
- Readiness check at port 8081 `/readyz`

## 🔄 Upgrade Process

To upgrade the operator:

1. Update CRDs first (if changed):
   ```bash
   kubectl apply -f 01-o2*.crd.yaml
   ```

2. Update ConfigMap if needed:
   ```bash
   kubectl apply -f 02-configmap.yaml
   ```

3. Apply new deployment:
   ```bash
   kubectl apply -f 03-deployment.yaml
   ```

The deployment uses RollingUpdate strategy with `maxUnavailable: 0` to ensure zero downtime.

## 🗑️ Uninstall

Remove all operator resources:

```bash
# Delete webhook configuration first
kubectl delete -f 04-webhook.yaml

# Delete deployment
kubectl delete -f 03-deployment.yaml

# Delete RBAC
kubectl delete -f 02-rbac.yaml

# Delete ConfigMap
kubectl delete -f 02-configmap.yaml

# Delete CRDs (this will delete all custom resources)
kubectl delete -f 01-o2*.crd.yaml

# Delete namespace (optional - will remove everything)
kubectl delete namespace o2operator
```

## 🐛 Troubleshooting

### Check operator status:
```bash
kubectl get pods -n o2operator
kubectl logs -n o2operator -l app=openobserve-operator
```

### Verify CRDs are installed:
```bash
kubectl get crds | grep openobserve
```

### Check webhook configuration:
```bash
kubectl get validatingwebhookconfiguration openobserve-validating-webhook
```

### View operator metrics:
```bash
kubectl port-forward -n o2operator svc/openobserve-metrics-service 8080:8080
curl http://localhost:8080/metrics
```

## 📝 Notes

- The operator watches all namespaces by default (configured via `WATCH_NAMESPACE=""`)
- Leader election is enabled for HA deployments
- Webhooks require TLS certificates (managed by cert-manager or manually)
- The operator image is pulled from AWS ECR (update the image path as needed)

## 🔗 Related Documentation

- [Production Deployment Guide](../../docs/production-deployment.md)
- [Local Development Setup](../../docs/local-deployment.md)
- [Controller Design Documents](../../design/)