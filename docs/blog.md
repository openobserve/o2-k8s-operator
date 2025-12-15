# Introducing the OpenObserve Kubernetes Operator: Observability as Code

**Published: December 2024**
**Version: v1.0.6**

---

## TL;DR

The OpenObserve Kubernetes Operator (o2-k8s-operator) brings the power of Infrastructure as Code to your observability stack. Manage alerts, pipelines, functions, destinations, and templates as native Kubernetes resources, enabling GitOps workflows and declarative configuration management for OpenObserve Enterprise.

---

## The Challenge: Managing Observability at Scale

As organizations scale their Kubernetes deployments, managing observability configurations becomes increasingly complex. Traditional approaches involving manual UI configuration or API scripts lead to:

- **Configuration drift** across environments (dev, test, prod)
- **Lack of version control** for critical alert definitions
- **Manual, error-prone deployments** of observability configurations
- **Difficulty in auditing changes** to monitoring and alerting
- **Inconsistent practices** across teams

What if you could manage your entire observability stack the same way you manage your applications - declaratively, with version control, and automated deployments?

---

## Enter the OpenObserve Kubernetes Operator

The o2-k8s-operator bridges the gap between Kubernetes-native workflows and OpenObserve Enterprise, transforming observability management into a first-class Kubernetes experience.

### What Makes It Special?

**🎯 Fully Declarative**
Define alerts, pipelines, functions, templates, and destinations as YAML manifests. No more clicking through UIs or running ad-hoc scripts.

**🔄 GitOps Ready**
Version control everything. Review changes through pull requests. Automate deployments with tools like ArgoCD, Flux, or your CI/CD pipeline of choice.

**🏢 Multi-Instance Support**
Manage multiple OpenObserve Enterprise instances (dev, test, prod) from a single Kubernetes cluster with isolated configurations.

**📊 Real-Time Status Tracking**
Get instant feedback on sync status, errors, and resource health through standard Kubernetes status conditions.

---

## Core Custom Resources

The operator introduces six powerful Custom Resource Definitions (CRDs):

### 1. **OpenObserveConfig** - Connection Management

Connect to your OpenObserve Enterprise instances with secure credential management:

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
  tlsVerify: true
```

### 2. **Alert** - Intelligent Monitoring

Define sophisticated alerts with multiple query types (SQL, PromQL, custom), flexible scheduling (cron, frequency), and advanced features like deduplication:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: Alert
metadata:
  name: high-error-rate
spec:
  configRef:
    name: production
  streamName: application-logs
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

### 3. **AlertTemplate** - Beautiful Notifications

Create reusable templates for Slack, PagerDuty, email, or any webhook with rich formatting:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveAlertTemplate
metadata:
  name: slack-template
spec:
  configRef:
    name: production
  name: slack-webhook-template
  type: http
  title: "🚨 Alert: {alert_name}"
  body: |
    {
      "text": "Alert Triggered",
      "blocks": [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Alert:* {alert_name}\n*Stream:* {stream_name}\n*Time:* {triggered_at}"
          }
        }
      ]
    }
```

### 4. **Destination** - Flexible Routing

Route alerts and pipeline data to multiple destinations (Slack, PagerDuty, email, SNS, Splunk, Elasticsearch, and more):

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveDestination
metadata:
  name: slack-alerts
spec:
  configRef:
    name: production
  name: slack-destination
  type: http
  url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
  method: post
  headers:
    Content-Type: application/json
  template: slack-template
```

### 5. **Function** - Data Transformation

Write VRL (Vector Remap Language) functions for powerful data transformations with built-in testing:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveFunction
metadata:
  name: data-enricher
spec:
  configRef:
    name: production
  name: enrich-logs
  function: |
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
        message: "Service unavailable"
    output:
      - error: "Connection timeout"
        message: "Service unavailable"
        processed_at: "2024-01-01T00:00:00Z"
        environment: "production"
        severity: "high"
```

### 6. **Pipeline** - Data Processing

Build sophisticated data processing pipelines with node-based architecture, scheduling, and transformation capabilities:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObservePipeline
metadata:
  name: error-log-processor
spec:
  configRef:
    name: production

  name: error-log-processor
  description: "Process error logs and route to multiple destinations"
  enabled: true
  org: default

  # Real-time source
  source:
    streamName: "application-logs"
    streamType: "logs"
    sourceType: "realtime"

  # Processing nodes
  nodes:
    # Filter for errors
    - id: "filter-errors"
      type: "condition"
      config:
        conditions:
          or:
            - column: "level"
              operator: "="
              value: "error"
            - column: "status_code"
              operator: ">="
              value: "500"

    # Transform with VRL function
    - id: "enrich-data"
      type: "function"
      config:
        function: "log-enricher"

    # Route to error stream
    - id: "error-output"
      type: "stream"
      config:
        org_id: "default"
        stream_name: "critical_errors"
        stream_type: "logs"

  # Data flow
  edges:
    - source: "source"
      target: "filter-errors"
    - source: "filter-errors"
      target: "enrich-data"
      condition: true
    - source: "enrich-data"
      target: "error-output"
```

**Advanced Pipeline Features:**
- **Real-time & Scheduled**: Process data as it arrives or on a schedule
- **Query-based Sources**: Use SQL or PromQL for batch processing
- **Multi-node Processing**: Chain transformations, filters, and routing
- **Branching Logic**: Route data to different destinations based on conditions
- **External Destinations**: Send to Splunk, Elasticsearch, Datadog, and more

---

## Real-World Use Cases

### Use Case 1: GitOps-Driven Observability

**Scenario**: A platform team needs to maintain consistent alerting across 50+ microservices spanning dev, test, and production environments.

**Solution with o2-k8s-operator**:
1. Store all alert definitions in Git alongside application code
2. Use ArgoCD to automatically deploy alerts when code changes are merged
3. Review alert changes through pull requests with team approval
4. Rollback problematic alerts with a simple Git revert

**Result**: Zero configuration drift, full audit trail, and 90% reduction in alert management overhead.

### Use Case 2: Multi-Tenant Observability

**Scenario**: A SaaS platform needs isolated observability configurations per customer environment.

**Solution with o2-k8s-operator**:
1. Deploy one OpenObserveConfig per customer namespace
2. Use namespace isolation for tenant-specific alerts and pipelines
3. Share common functions and templates across namespaces
4. Manage everything through a single Kubernetes cluster

**Result**: Secure multi-tenancy with simplified operations.

### Use Case 3: Automated Incident Response

**Scenario**: DevOps team wants alerts to automatically create PagerDuty incidents, post to Slack, and send email summaries.

**Solution with o2-k8s-operator**:
1. Define alert templates for each notification channel
2. Create destinations for PagerDuty, Slack, and email
3. Reference all destinations in a single alert definition
4. Let the operator handle synchronization and delivery

**Result**: Rich, consistent notifications across all channels with zero manual configuration.

---

## Enterprise-Grade Features

### 🔐 Security First

- **Secret Management**: Credentials stored as Kubernetes Secrets
- **TLS Security**: Auto-generated certificates for webhooks
- **RBAC Controls**: Granular permission management
- **Container Security**: Non-root user, read-only filesystem, dropped capabilities
- **Pod Security**: Security contexts, resource limits, seccomp profiles

### 📈 Performance & Scalability

- **High Availability**: Default 2-replica deployment with leader election
- **Configurable Concurrency**: Tune controller performance per resource type
- **Rate Limiting**: Protect OpenObserve API with configurable limits
- **Connection Pooling**: Efficient HTTP connection management
- **Resource Optimization**: Fine-tuned CPU and memory limits

**Performance Tuning Example** (via ConfigMap):
```yaml
ALERT_CONTROLLER_CONCURRENCY: "5"
O2_RATE_LIMIT_RPS: "50"
O2_MAX_CONNS_PER_HOST: "20"
```

### 📊 Observability for Your Observability

- **Health Probes**: `/healthz`, `/readyz`, `/startup` endpoints
- **Prometheus Metrics**: Controller performance metrics at `/metrics`
- **Status Tracking**: Real-time sync status with detailed conditions
- **Event Recording**: Kubernetes events for important operations

---

## Getting Started in 5 Minutes

### 1. Deploy the Operator

```bash
./deploy.sh
```

### 2. Configure Connection

```bash
kubectl apply -f configs/prod/o2prod-config.yaml
```

### 3. Deploy Your First Alert

```bash
kubectl apply -f samples/alerts/high-cpu-alert.yaml
```

### 4. Check Status

```bash
kubectl get alerts
kubectl describe alert high-cpu-alert
```

That's it! Your alert is now managed declaratively and synced with OpenObserve Enterprise.

---

## Architecture Highlights

### Continuous Reconciliation
The operator continuously ensures your desired state (Kubernetes resources) matches actual state (OpenObserve configurations):

1. **Watch**: Monitors Kubernetes API for resource changes
2. **Reconcile**: Syncs changes to OpenObserve Enterprise
3. **Update Status**: Reports back success or errors
4. **Retry**: Automatic retry with exponential backoff on failures

### Zero-Downtime Updates
- Rolling deployments for operator upgrades
- Leader election prevents split-brain scenarios
- PodDisruptionBudget ensures availability during cluster maintenance
- Anti-affinity rules spread replicas across nodes

---

## Community & Support

### 🤝 Get Involved

- **GitHub**: [openobserve/o2-k8s-operator](https://github.com/openobserve/o2-k8s-operator)
- **Issues**: Report bugs or request features
- **Community Forum**: Share use cases and best practices

### 📚 Resources

- [Complete Documentation](../README.md)
- [API Reference](O2OPERATOR_FEATURES.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Sample Configurations](../samples/)

---

## Why It Matters

The o2-k8s-operator represents a fundamental shift in how organizations manage observability:

✅ **From manual → automated**
✅ **From GUI-driven → code-driven**
✅ **From scattered → centralized**
✅ **From undocumented → version-controlled**
✅ **From fragile → reliable**

By treating observability configurations as code, teams can apply the same rigorous engineering practices they use for applications: code review, testing, CI/CD, and automated rollbacks.

---

## Conclusion

The OpenObserve Kubernetes Operator (v1.0.6) brings enterprise-grade observability management to Kubernetes-native environments. Whether you're running a small development cluster or managing observability at scale across hundreds of services, the operator provides the foundation for reliable, automated, and auditable observability operations.

**Ready to get started?**

```bash
git clone https://github.com/openobserve/o2-k8s-operator
cd o2-k8s-operator
./deploy.sh
```

Join the growing community of teams adopting observability-as-code practices with the o2-k8s-operator.

---

**About OpenObserve**: OpenObserve is a cloud-native observability platform designed for logs, metrics, and traces. OpenObserve Enterprise provides advanced features including APIs for automation, which the o2-k8s-operator leverages to provide Kubernetes-native resource management.

---

*Have questions or feedback? Open an issue on [GitHub](https://github.com/openobserve/o2-k8s-operator/issues) or join our [community forum](https://short.openobserve.ai/community).*
