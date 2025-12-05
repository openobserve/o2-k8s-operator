# OpenObserve Pipeline Samples

This directory contains example pipeline configurations for the OpenObserve Kubernetes Operator. Pipelines enable automated data processing, transformation, and routing between different streams and destinations.

## Overview

The OpenObserve Pipeline CRD (`OpenObservePipeline`) allows you to create data processing workflows that:
- **Transform** data using VRL functions and conditions
- **Route** data between different streams and destinations
- **Aggregate** data with SQL or PromQL queries
- **Schedule** batch processing at defined intervals
- **Filter** data based on complex conditions

## Pipeline Architecture

Pipelines consist of:
1. **Source**: Input data stream or query
2. **Nodes**: Processing steps (transform, filter, route)
3. **Edges**: Connections between nodes
4. **Destinations**: Output targets for processed data

```
Source → Node1 (Filter) → Node2 (Transform) → Node3 (Route) → Destination
                ↓                                    ↓
            Dropped                           Destination2
```

## Prerequisites

Before using these samples:

1. **Deploy the OpenObserve Operator**
   ```bash
   ./deploy.sh
   ```

2. **Configure OpenObserve Connection**
   ```bash
   kubectl apply -f configs/dev/o2dev-config.yaml
   ```

3. **Create Functions** (if using transformation nodes)
   ```bash
   kubectl apply -f samples/functions/
   ```

4. **Create Destinations** (if routing to external systems)
   ```bash
   kubectl apply -f samples/destinations/
   ```

## Sample Files

### Real-Time Pipelines

Process data as it arrives in streams, enabling immediate transformation and routing.

| File | Complexity | Description | Key Features |
|------|------------|-------------|--------------|
| `real-time-pipeline1.yaml` | Simple | Basic source to destination routing | Direct data flow, minimal configuration |
| `real-time-pipeline2.yaml` | Intermediate | Source → Transform → Destination | VRL function transformation |
| `real-time-pipeline3.yaml` | Advanced | Multi-node with branching | Conditions, routing, multiple destinations |

### SQL Query Pipelines

Schedule SQL queries to process batch data at intervals.

| File | Complexity | Description | Key Features |
|------|------------|-------------|--------------|
| `sql-query-pipeline1.yaml` | Simple | Basic SQL query to destination | Simple SELECT, scheduled execution |
| `sql-query-pipeline2.yaml` | Intermediate | SQL with transformation | Query results transformation |
| `sql-query-pipeline3.yaml` | Advanced | Complex SQL with multi-routing | Aggregations, conditions, branching |

### PromQL Query Pipelines

Schedule PromQL queries for metrics processing and alerting.

| File | Complexity | Description | Key Features |
|------|------------|-------------|--------------|
| `promql-query-pipeline1.yaml` | Simple | Basic metric query | Simple PromQL, threshold checking |
| `promql-query-pipeline2.yaml` | Intermediate | Metrics with conditions | PromQL conditions, transformations |
| `promql-query-pipeline3.yaml` | Advanced | Complex metric processing | Rate calculations, aggregations, routing |

## Pipeline Configuration Structure

### Basic Structure

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObservePipeline
metadata:
  name: <pipeline-name>
  namespace: o2operator
spec:
  configRef:
    name: openobserve-main
    namespace: o2operator

  name: <pipeline-identifier>  # Pipeline name in OpenObserve
  description: <description>    # Human-readable description
  enabled: true                  # Enable/disable pipeline
  org: <organization>           # Organization name

  source: {}                    # Input configuration
  nodes: []                     # Processing nodes
  edges: []                     # Node connections
```

## Source Configuration

### 1. Real-Time Source

Processes data as it arrives:

```yaml
source:
  streamName: "application_logs"
  streamType: "logs"           # logs, metrics, or traces
  sourceType: "realtime"        # Default for real-time processing
```

### 2. Scheduled Query Source (SQL)

Batch processing with SQL queries:

```yaml
source:
  sourceType: "scheduled"
  streamType: "logs"
  queryCondition:
    type: "sql"
    sql: |
      SELECT
        COUNT(*) as error_count,
        service,
        MAX(timestamp) as last_error
      FROM logs
      WHERE level = 'error'
      GROUP BY service
      HAVING error_count > 10
    searchEventType: "derivedstream"

  triggerCondition:
    period: 10              # Time window in minutes
    frequency: 5            # Run every 5 minutes
    frequencyType: "minutes"
    timezone: "UTC"
```

### 3. Scheduled Query Source (PromQL)

Metrics processing with PromQL:

```yaml
source:
  sourceType: "scheduled"
  streamType: "metrics"
  queryCondition:
    type: "promql"
    promql: "rate(http_requests_total[5m])"
    promqlCondition:
      column: "value"
      operator: ">"
      value: 100
    searchEventType: "derivedstream"

  triggerCondition:
    period: 5
    frequency: 1
    frequencyType: "minutes"
```

## Node Types

### 1. Stream Node (Destination)

Routes data to a stream or external destination:

```yaml
nodes:
  - id: "output_node"
    type: "stream"
    data:
      node_type: "stream"
      org: "default"
      streamName: "processed_logs"     # Target stream
      streamType: "logs"
      # OR for external destination:
      destination: "splunk-destination"  # Reference destination name
```

### 2. Condition Node

Filters data based on conditions:

```yaml
nodes:
  - id: "filter_errors"
    type: "condition"
    data:
      node_type: "condition"
      conditions:
        or:
          - column: "level"
            operator: "="
            value: "error"
          - column: "status_code"
            operator: ">="
            value: "500"
```

### 3. Query Node

Executes queries on data:

```yaml
nodes:
  - id: "aggregate_data"
    type: "query"
    data:
      node_type: "query"
      query:
        type: "sql"
        sql: |
          SELECT
            service,
            COUNT(*) as count,
            AVG(response_time) as avg_time
          FROM input
          GROUP BY service
```

### 4. Function Node

Applies VRL transformation functions:

```yaml
nodes:
  - id: "transform_data"
    type: "function"
    data:
      node_type: "function"
      function: "k8s_log_processor"  # Reference to OpenObserveFunction
```

## Edge Configuration

Edges connect nodes to define data flow:

```yaml
edges:
  - source: "source"          # Source or node ID
    target: "filter_errors"   # Target node ID

  - source: "filter_errors"
    target: "transform_data"
    condition: true           # Only matching data flows

  - source: "filter_errors"
    target: "dropped"         # Non-matching data
    condition: false
```

## Common Pipeline Patterns

### 1. Simple ETL Pipeline

Extract → Transform → Load:

```yaml
# Source (Extract)
source:
  streamName: "raw_logs"
  streamType: "logs"

# Nodes
nodes:
  # Transform
  - id: "transform"
    type: "function"
    data:
      function: "log_enrichment"

  # Load
  - id: "output"
    type: "stream"
    data:
      streamName: "enriched_logs"

# Edges
edges:
  - source: "source"
    target: "transform"
  - source: "transform"
    target: "output"
```

### 2. Data Routing Pipeline

Route data to different destinations based on conditions:

```yaml
nodes:
  # Condition for critical errors
  - id: "check_critical"
    type: "condition"
    data:
      conditions:
        column: "severity"
        operator: "="
        value: "critical"

  # Route critical to PagerDuty
  - id: "pagerduty_out"
    type: "stream"
    data:
      destination: "pagerduty-alerts"

  # Route others to Slack
  - id: "slack_out"
    type: "stream"
    data:
      destination: "slack-notifications"

edges:
  - source: "check_critical"
    target: "pagerduty_out"
    condition: true

  - source: "check_critical"
    target: "slack_out"
    condition: false
```

### 3. Aggregation Pipeline

Aggregate data before sending:

```yaml
source:
  sourceType: "scheduled"
  queryCondition:
    type: "sql"
    sql: |
      SELECT
        service,
        error_level,
        COUNT(*) as error_count,
        MIN(timestamp) as first_occurrence,
        MAX(timestamp) as last_occurrence
      FROM logs
      WHERE level IN ('error', 'critical')
      GROUP BY service, error_level
      HAVING error_count > 5

nodes:
  - id: "alert_destination"
    type: "stream"
    data:
      destination: "alert-aggregator"
```

### 4. Multi-Branch Pipeline

Process data through multiple paths:

```yaml
nodes:
  # Initial filter
  - id: "filter_logs"
    type: "condition"
    data:
      conditions:
        column: "log_type"
        operator: "IN"
        value: ["application", "system", "security"]

  # Branch 1: Application logs
  - id: "app_processor"
    type: "function"
    data:
      function: "app_log_enrichment"

  # Branch 2: System logs
  - id: "system_processor"
    type: "function"
    data:
      function: "system_log_parser"

  # Branch 3: Security logs
  - id: "security_analyzer"
    type: "function"
    data:
      function: "security_threat_detection"

  # Outputs
  - id: "app_output"
    type: "stream"
    data:
      streamName: "processed_app_logs"

  - id: "system_output"
    type: "stream"
    data:
      streamName: "processed_system_logs"

  - id: "security_output"
    type: "stream"
    data:
      streamName: "security_alerts"
```

## Deployment

### Deploy a Single Pipeline

```bash
# Deploy a real-time pipeline
kubectl apply -f samples/pipelines/real-time-pipeline1.yaml

# Check pipeline status
kubectl get openobservepipelines -n o2operator
```

### Deploy All Pipelines of a Type

```bash
# Deploy all real-time pipelines
kubectl apply -f samples/pipelines/real-time-*.yaml

# Deploy all SQL query pipelines
kubectl apply -f samples/pipelines/sql-query-*.yaml

# Deploy all PromQL pipelines
kubectl apply -f samples/pipelines/promql-query-*.yaml
```

### Verify Pipeline Creation

```bash
# Get pipeline details
kubectl describe openobservepipeline real-time-pipeline1 -n o2operator

# Check operator logs
kubectl logs -n o2operator deployment/openobserve-operator | grep pipeline
```

## Best Practices

### 1. Pipeline Design
- **Single Responsibility**: Each pipeline should have one clear purpose
- **Modularity**: Use functions for reusable transformations
- **Error Handling**: Include error routing paths
- **Documentation**: Add clear descriptions to pipelines

### 2. Performance
- **Batch Size**: Configure appropriate batch sizes for scheduled pipelines
- **Query Optimization**: Optimize SQL/PromQL queries for large datasets
- **Node Count**: Minimize node count for better performance
- **Parallel Processing**: Use multiple pipelines for parallel workloads

### 3. Scheduling
- **Off-Peak Hours**: Schedule heavy queries during low-traffic periods
- **Frequency**: Balance between data freshness and system load
- **Time Windows**: Use appropriate time windows for aggregations
- **Timezone**: Set correct timezone for scheduled pipelines

### 4. Data Quality
- **Validation**: Add condition nodes to validate data
- **Deduplication**: Handle duplicate data appropriately
- **Missing Data**: Handle null/missing fields gracefully
- **Data Types**: Ensure consistent data types through pipeline

### 5. Monitoring
- **Metrics**: Monitor pipeline execution metrics
- **Errors**: Set up alerting for pipeline failures
- **Throughput**: Track data processing rates
- **Latency**: Monitor end-to-end processing time

## Troubleshooting

### Pipeline Not Processing Data

1. **Check Pipeline Status**:
   ```bash
   kubectl get openobservepipeline <name> -n o2operator -o yaml
   ```

2. **Verify Source Stream**: Ensure source stream exists and has data

3. **Check Node Configuration**: Verify all referenced functions/destinations exist

4. **Review Operator Logs**:
   ```bash
   kubectl logs -n o2operator deployment/openobserve-operator | grep <pipeline-name>
   ```

### Data Not Reaching Destination

1. **Check Edge Configuration**: Verify edges connect all nodes correctly
2. **Review Condition Logic**: Ensure conditions aren't filtering all data
3. **Verify Destination**: Confirm destination exists and is accessible
4. **Check Transform Functions**: Ensure functions aren't dropping required fields

### Scheduled Pipeline Not Running

1. **Check Schedule Configuration**: Verify frequency and timezone settings
2. **Review Query Syntax**: Validate SQL/PromQL queries in OpenObserve UI
3. **Check Time Windows**: Ensure period settings match available data
4. **Verify Permissions**: Confirm pipeline has access to queried streams

### Performance Issues

1. **Optimize Queries**: Simplify complex SQL/PromQL queries
2. **Reduce Node Count**: Combine operations where possible
3. **Adjust Batch Size**: Configure appropriate batch sizes
4. **Check Resource Limits**: Verify operator has sufficient resources

## Advanced Configuration

### Custom Node Data

Nodes can include custom configuration:

```yaml
nodes:
  - id: "custom_node"
    type: "custom"
    data:
      node_type: "custom"
      custom_config:
        parameter1: "value1"
        parameter2: 100
        nested:
          key: "value"
```

### Dynamic Routing

Use conditions for dynamic routing:

```yaml
edges:
  - source: "classifier"
    target: "high_priority"
    condition:
      column: "priority"
      operator: ">="
      value: 8

  - source: "classifier"
    target: "normal_priority"
    condition:
      column: "priority"
      operator: "<"
      value: 8
```

### Pipeline Chaining

Connect multiple pipelines:

```yaml
# Pipeline 1: Output to stream
nodes:
  - id: "output"
    type: "stream"
    data:
      streamName: "intermediate_stream"

# Pipeline 2: Input from intermediate stream
source:
  streamName: "intermediate_stream"
  streamType: "logs"
```

## Integration Examples

### With Functions

```yaml
nodes:
  - id: "enrich_data"
    type: "function"
    data:
      function: "k8s_metadata_enrichment"
```

### With Destinations

```yaml
nodes:
  - id: "send_to_splunk"
    type: "stream"
    data:
      destination: "splunk-destination"
```

### With Alerts

Pipelines can trigger alerts by routing data to streams monitored by alerts:

```yaml
nodes:
  - id: "alert_stream"
    type: "stream"
    data:
      streamName: "alert_trigger_stream"  # Monitored by alert
```

## Additional Resources

- [OpenObserve Pipeline Documentation](https://openobserve.ai/docs/pipelines)
- [VRL Function Samples](../functions/README.md)
- [Destination Configuration](../destinations/README.md)
- [Alert Samples](../alerts/README.md)
- [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)

## Contributing

To add new pipeline samples:
1. Create a YAML file following naming conventions
2. Include comprehensive comments
3. Test the pipeline with real data
4. Document use cases and requirements
5. Update this README

For questions or issues, please [open an issue](https://github.com/openobserve/o2-k8s-operator/issues) on GitHub.