# OpenObserve Alert Samples

This directory contains example alert configurations for the OpenObserve Kubernetes Operator. These samples demonstrate various alert types, query conditions, and monitoring strategies for logs, metrics, and traces.

## Overview

The OpenObserve Alert CRD (`OpenObserveAlert`) allows you to define alerts that monitor your data streams and trigger notifications when specific conditions are met. These samples showcase different alert configurations based on:

- **Stream Types**: Logs, Metrics, and Traces
- **Alert Types**: Real-time and Scheduled alerts
- **Query Types**: Custom, SQL, and PromQL queries

## Prerequisites

Before using these samples:

1. **Deploy the OpenObserve Operator**
   ```bash
   ./deploy.sh
   ```

2. **Configure OpenObserve Connection**
   Create an OpenObserveConfig resource named `openobserve-main` in the `o2operator` namespace:
   ```bash
   kubectl apply -f configs/dev/o2dev-config.yaml
   ```

3. **Create Alert Destinations** (Optional)
   If your alerts reference destinations, create them first:
   ```bash
   kubectl apply -f samples/destinations/
   ```

## Sample Files

### Real-Time Alerts

Real-time alerts monitor data streams continuously and trigger immediately when conditions are met.

| File | Description | Stream Type | Use Case |
|------|-------------|-------------|-----------|
| `real-time-logs-alert.yaml` | Real-time monitoring of log streams | Logs | Monitor application logs for errors or specific patterns in real-time |
| `real-time-metrics-alert.yaml` | Real-time metrics monitoring with custom conditions | Metrics | Track metric thresholds and anomalies as they occur |
| `real-time-traces-alert.yaml` | Real-time trace monitoring | Traces | Monitor distributed traces for latency issues or errors |

### Scheduled Alerts

Scheduled alerts run queries at defined intervals to check for conditions over time windows.

| File | Description | Stream Type | Query Type | Use Case |
|------|-------------|-------------|------------|-----------|
| `scheduled-custom-logs-alert.yaml` | Scheduled custom query on logs | Logs | Custom | Complex log analysis with custom conditions |
| `scheduled-custom-metrics-alert.yaml` | Scheduled custom query on metrics | Metrics | Custom | Periodic metric evaluation with aggregations |
| `scheduled-custom-traces-alert.yaml` | Scheduled custom query on traces | Traces | Custom | Batch analysis of trace data |
| `scheduled-sql-logs-alert.yaml` | SQL-based scheduled alert for logs | Logs | SQL | Use SQL queries for log analysis |
| `scheduled-sql-metrics-alert.yaml` | SQL-based scheduled alert for metrics | Metrics | SQL | SQL-based metric aggregations and thresholds |
| `scheduled-sql-traces-alert.yaml` | SQL-based scheduled alert for traces | Traces | SQL | SQL analysis of trace spans |
| `scheduled-promql-alert.yaml` | PromQL-based scheduled alert | Metrics | PromQL | Prometheus-compatible metric queries |

## Alert Configuration Structure

Each alert sample follows this basic structure:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveAlert
metadata:
  name: <alert-name>
  namespace: o2operator
spec:
  configRef:
    name: openobserve-main     # Reference to OpenObserveConfig
    namespace: o2operator

  # Basic Configuration
  name: <alert-identifier>     # Unique alert name in OpenObserve
  enabled: true                 # Enable/disable the alert
  description: <description>    # Alert description
  streamName: <stream>          # Target stream name
  streamType: <logs|metrics|traces>

  # Alert Type
  isRealTime: <true|false>      # Real-time or scheduled

  # Query Configuration
  queryCondition:
    type: <custom|sql|promql>
    # Query-specific configuration

  # Schedule (for non-real-time alerts)
  schedule:
    frequency: <minutes>
    frequencyType: <minutes|hours|days>

  # Notification Destinations
  destinations:
    - <destination-name>
```

## Usage Examples

### Deploy a Single Alert

```bash
# Deploy a real-time log alert
kubectl apply -f samples/alerts/real-time-logs-alert.yaml

# Check alert status
kubectl get openobservealerts -n o2operator
```

### Deploy All Real-Time Alerts

```bash
kubectl apply -f samples/alerts/real-time-*.yaml
```

### Deploy All Scheduled Alerts

```bash
kubectl apply -f samples/alerts/scheduled-*.yaml
```

### View Alert Details

```bash
# Get alert status
kubectl describe openobservealert real-time-logs-alert -n o2operator

# Check alert logs
kubectl logs -n o2operator deployment/openobserve-operator | grep real-time-logs-alert
```

## Customization Guide

### Modifying Query Conditions

#### Custom Query with Conditions
```yaml
queryCondition:
  type: custom
  conditions:
    or:
      - column: level
        operator: "="
        value: "error"
      - column: status_code
        operator: ">="
        value: "500"
```

#### SQL Query
```yaml
queryCondition:
  type: sql
  sql: |
    SELECT COUNT(*) as error_count
    FROM logs
    WHERE level = 'error'
    GROUP BY service
    HAVING error_count > 100
```

#### PromQL Query
```yaml
queryCondition:
  type: promql
  promql: |
    rate(http_requests_total{status=~"5.."}[5m]) > 0.1
```

### Adding Aggregations

```yaml
queryCondition:
  aggregation:
    groupBy:
      - "service"
      - "environment"
    function: "count"
    having:
      column: "_count"
      operator: ">="
      value: 100
```

### Configuring Alert Schedule

```yaml
schedule:
  frequency: 5
  frequencyType: "minutes"
  period: 10              # Time window in minutes
  timezone: "UTC"
```

### Adding Destinations

```yaml
destinations:
  - slack-alerts
  - pagerduty-critical
  - email-team
```

## Best Practices

1. **Start with Real-Time Alerts** for critical issues that need immediate attention
2. **Use Scheduled Alerts** for trend analysis and periodic reporting
3. **Test with Lower Thresholds** initially to ensure alerts are working
4. **Use Descriptive Names** that clearly indicate what the alert monitors
5. **Group Related Alerts** in folders using the `folderName` field
6. **Enable Deduplication** for high-frequency alerts to avoid alert fatigue
7. **Use SQL/PromQL** for complex queries that are easier to express in those languages

## Troubleshooting

### Alert Not Triggering
- Check if the alert is enabled (`enabled: true`)
- Verify the stream name and type match your data
- Review query conditions and thresholds
- Check OpenObserve logs for query execution errors

### Connection Issues
- Ensure OpenObserveConfig is correctly configured
- Verify credentials in the referenced secret
- Check network connectivity to OpenObserve instance

### Query Errors
- Validate SQL/PromQL syntax in OpenObserve UI first
- Check field names match your data schema
- Ensure time ranges are appropriate for your data

## Additional Resources

- [OpenObserve Alert Documentation](https://openobserve.ai/docs/alerts)
- [Alert Template Samples](../alerttemplates/README.md)
- [Destination Configuration](../destinations/README.md)
- [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)

## Contributing

To add new alert samples:
1. Create a new YAML file following the naming convention
2. Include comprehensive comments explaining the use case
3. Test the alert with actual data
4. Update this README with the new sample information

For questions or issues, please [open an issue](https://github.com/openobserve/o2-k8s-operator/issues) on GitHub.