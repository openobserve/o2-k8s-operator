# OpenObserve Kubernetes Operator Features

## Overview

The OpenObserve Kubernetes Operator provides a comprehensive set of features for managing OpenObserve Enterprise resources through Kubernetes-native Custom Resources. This document outlines all available features organized by category, including alerts, pipelines, functions, and configurations.

## Core Features

### 🎯 Declarative Resource Management
- **Native Kubernetes Integration**: Manage OpenObserve resources as standard Kubernetes Custom Resource Definitions (CRDs)
- **GitOps Ready**: Full support for GitOps workflows with version control and automated deployments
- **Infrastructure as Code**: Define and manage observability configurations alongside application deployments
- **Multi-Instance Support**: Manage multiple OpenObserve instances from a single Kubernetes cluster
- **Comprehensive Resource Types**: Manage alerts, pipelines, functions, and configurations as code

### 🔄 Automated Lifecycle Management
- **Resource Synchronization**: Automatic sync between Kubernetes resources and OpenObserve configurations
- **Status Tracking**: Real-time monitoring of resource sync status with detailed condition reporting
- **Generation Tracking**: Tracks resource generations to ensure consistency between desired and actual states
- **Finalizer Support**: Proper cleanup of OpenObserve resources when Kubernetes resources are deleted
- **Resource Types**: Full lifecycle management for alerts, pipelines, functions, and configurations

## Custom Resource Definitions (CRDs)

### 1. OpenObserveConfig (o2config)

Manages connection configurations to OpenObserve instances.

**Key Features:**
- **Secure Credential Management**: Credentials stored as Kubernetes Secrets
- **Multiple Instance Support**: Configure connections to different OpenObserve environments (dev, test, prod)
- **TLS Configuration**: Optional TLS verification settings
- **Organization Scoping**: Organization-level configuration management
- **Connection Validation**: Automatic validation of endpoint connectivity

**Configuration Options:**
- `endpoint`: OpenObserve API endpoint URL
- `organization`: Target organization name
- `credentialsSecretRef`: Reference to Kubernetes Secret containing API tokens
- `tlsVerify`: Enable/disable TLS certificate verification

### 2. OpenObserveAlert (o2alert)

Manages alert definitions with comprehensive monitoring capabilities.

**Key Features:**

#### Query Capabilities
- **Multiple Query Types**:
  - Custom queries
  - SQL-based queries
  - PromQL queries for metrics
- **Stream Support**: Works with logs, metrics, and traces
- **Aggregation Functions**: Support for groupBy, having clauses, and various aggregation functions
- **VRL Functions**: Vector Remap Language function support
- **Multi-Time Range**: Compare data across different time windows

#### Trigger Conditions
- **Flexible Scheduling**:
  - Frequency-based triggers (minutes, hours, days)
  - Cron expression support
  - Time window configuration (period)
- **Threshold Management**:
  - Multiple comparison operators (=, !=, >=, <=, >, <)
  - Configurable thresholds
  - Silence periods to prevent alert fatigue
- **Advanced Options**:
  - Timezone support
  - Tolerance settings (toleranceInSecs)
  - Time alignment options

#### Alert Management
- **Real-time Alerts**: Support for real-time alert processing
- **Deduplication**:
  - Fingerprint-based deduplication
  - Configurable time windows
  - Custom fingerprint fields
- **Context Enrichment**:
  - Context attributes for additional metadata
  - Row templates (String or JSON format)
  - Custom template variables

#### Organization & Delivery
- **Folder Organization**: Support for organizing alerts in folders
- **Multiple Destinations**: Up to 10 destination channels per alert
- **Status Tracking**:
  - Alert enablement status
  - Last sync time
  - OpenObserve alert ID tracking

### 3. OpenObserveFunction (o2function, o2func)

Manages VRL (Vector Remap Language) transformation functions for data processing.

**Key Features:**

#### Function Management
- **VRL Support**: Write functions in Vector Remap Language for powerful data transformations
- **Reusable Functions**: Create centralized functions that can be used across multiple pipelines
- **Organization Scoping**: Functions are created at the organization level
- **Name Validation**: Enforced naming patterns for consistency

#### Testing & Validation
- **Built-in Testing**: Define test cases with input and expected output
- **Test Execution**: Automatic validation of function logic during deployment
- **Error Reporting**: Detailed error messages for failed tests
- **Multiple Test Cases**: Support for multiple test scenarios per function

#### Use Cases
- **Data Transformation**: Modify, enrich, or restructure log data
- **Field Extraction**: Parse and extract fields from unstructured data
- **Data Enrichment**: Add contextual information to events
- **Format Conversion**: Convert between different data formats
- **Filtering**: Implement complex filtering logic
- **Aggregation**: Perform custom aggregations on data streams

#### Integration
- **Pipeline Integration**: Functions can be referenced in pipelines for data processing
- **Stream Compatibility**: Works with logs, metrics, and traces
- **Version Tracking**: Generation tracking for function updates
- **Status Monitoring**: Real-time sync status with OpenObserve

### 4. OpenObservePipeline (o2pipeline)

Manages data processing pipelines with advanced transformation capabilities.

**Key Features:**

#### Source Configuration
- **Multiple Source Types**:
  - Real-time data sources
  - Scheduled/batch sources
  - Query-based sources
- **Stream Types**: Logs, metrics, and traces
- **Flexible Scheduling**:
  - Cron expressions
  - Frequency-based schedules
  - Time-based triggers

#### Pipeline Processing
- **Node-Based Architecture**:
  - Modular node system for data processing
  - Configurable node parameters
  - Support for various transformation types
- **Edge Connections**:
  - Define data flow between nodes
  - Support for branching pipelines
  - Multiple processing paths

#### Advanced Features
- **Version Control**: Pipeline versioning support
- **Pause/Resume**: Ability to pause pipelines at specific points
- **Error Handling**: Detailed error tracking and reporting
- **Delay Configuration**: Configurable processing delays
- **Timezone Support**: Per-pipeline timezone configuration

## Deployment & Operations Features

### 🚀 Automated Deployment
- **One-Command Deployment**: Simple deployment script with customizable options
- **Image Configuration**: Support for custom container images and tags
- **Namespace Management**: Flexible namespace configuration
- **RBAC Setup**: Automatic creation of required roles and permissions

### 🔐 Security Features
- **Webhook Security**:
  - Auto-generated TLS certificates for webhooks
  - Certificate rotation support
  - Secure admission control
- **Secret Management**:
  - Kubernetes-native secret handling
  - Credential isolation per namespace
- **RBAC Controls**:
  - Granular permission management
  - Cluster and namespace-scoped roles

### 📊 Monitoring & Observability
- **Status Reporting**:
  - Detailed condition tracking (Ready, Synced, Error states)
  - Last sync timestamps
  - Error messages and reasons
- **Custom Printer Columns**:
  - Quick status overview in kubectl output
  - Key field visibility (Stream, Enabled, Ready, Age)
- **Generation Tracking**: Version tracking for resource updates

## Advanced Capabilities

### 🔄 Reconciliation Features
- **Continuous Reconciliation**: Ensures desired state matches actual state
- **Error Recovery**: Automatic retry with exponential backoff
- **Drift Detection**: Identifies and corrects configuration drift
- **Resource Validation**: Pre-flight validation before applying changes

### 🎛️ Operational Features
- **Dry Run Support**: Preview changes before applying
- **Uninstall Management**:
  - Complete cleanup with finalizer removal
  - Ordered resource deletion (alerts, pipelines, functions, configurations)
  - Namespace cleanup
- **Multi-Environment Support**:
  - Development, test, and production configurations
  - Environment-specific templates

### 🔧 Developer Features
- **Sample Templates**: Comprehensive examples for all resource types (alerts, pipelines, functions)
- **Validation Webhooks**: Input validation at admission time
- **Status Subresources**: Proper status update mechanisms
- **Preserved Unknown Fields**: Future compatibility for API extensions

## Integration Capabilities

### GitOps Integration
- **Flux Compatibility**: Works with Flux CD for automated deployments
- **ArgoCD Support**: Compatible with ArgoCD for application management
- **Helm Integration**: Can be deployed via Helm charts

### CI/CD Integration
- **Pipeline Integration**: Integrates with CI/CD pipelines
- **Automated Testing**: Support for automated configuration testing
- **Version Control**: Full compatibility with Git workflows

## Resource Organization

### Namespace Support
- **Multi-tenancy**: Isolate resources by namespace
- **Cross-namespace References**: Support for referencing configs across namespaces
- **Default Namespace**: Configurable default namespace for resources

### Resource Relationships
- **Config References**: Resources reference OpenObserveConfig for connection details
- **Dependency Management**: Proper handling of resource dependencies
- **Cascading Updates**: Updates propagate through dependent resources

## Operational Excellence

### High Availability
- **Stateless Operation**: Operator maintains no local state
- **Horizontal Scaling**: Support for multiple operator replicas
- **Leader Election**: Proper coordination for multiple instances

### Performance
- **Efficient Reconciliation**: Optimized reconciliation loops
- **Batch Processing**: Bulk operations where applicable
- **Resource Caching**: Minimizes API calls to OpenObserve

### Maintenance
- **Zero-Downtime Updates**: Rolling updates for operator upgrades
- **Backward Compatibility**: API version compatibility management
- **Migration Support**: Tools for migrating between versions

## Troubleshooting & Debugging

### Diagnostic Features
- **Detailed Logging**: Comprehensive operator logs
- **Event Recording**: Kubernetes events for important operations
- **Status Conditions**: Detailed condition reporting for debugging

### Documentation & Support
- **Comprehensive Documentation**:
  - API references
  - Troubleshooting guides
  - Deployment instructions
- **Sample Configurations**: Ready-to-use examples for common scenarios
- **Issue Tracking**: GitHub integration for bug reports and features

## Future-Ready Design

### Extensibility
- **CRD Versioning**: Support for multiple API versions
- **Custom Fields**: Preserved unknown fields for future extensions
- **Plugin Architecture**: Designed for future plugin support

### Scalability
- **Resource Limits**: Configurable limits (e.g., max 10 alert destinations)
- **Pagination Support**: Ready for large-scale deployments
- **Bulk Operations**: Designed for batch processing capabilities

## 🚧 Development In-Progress

The following features are currently under active development and will be available in upcoming releases:

### OpenObserveAlertDestinations (o2alertdest)

A dedicated Custom Resource for managing alert notification destinations as independent resources.

**Planned Features:**
- **Destination Types**:
  - Slack channels
  - Email (SMTP)
  - PagerDuty
  - OpsGenie
  - Microsoft Teams
  - Webhooks
  - Discord
  - Telegram
  - Custom HTTP endpoints

- **Configuration Management**:
  - Centralized credential storage
  - Template management for notifications
  - Custom formatting per destination
  - Rate limiting and throttling
  - Retry policies
  - Delivery confirmation tracking

- **Advanced Features**:
  - Alert routing rules
  - Severity-based filtering
  - Time-based routing (business hours, on-call schedules)
  - Alert aggregation and batching
  - Escalation policies
  - Acknowledgment tracking
  - Two-way integrations

**Integration with Alerts:**
- Reference destinations by name in alert configurations
- Share destinations across multiple alerts
- Dynamic destination selection based on alert attributes
- Multi-channel notifications
- Fallback destination support

### OpenObserveRemoteDestinations (o2remotedest)

A Custom Resource for managing remote data destinations for pipelines and data export.

**Planned Features:**
- **Destination Types**:
  - OpenObserve clusters (cross-cluster replication)
  - Object storage (S3, GCS, Azure Blob Storage)
  - Message queues (Kafka, RabbitMQ, Amazon SQS, Azure Service Bus)
  - Time-series databases (InfluxDB, Prometheus, VictoriaMetrics)
  - Data warehouses (Snowflake, BigQuery, Redshift)
  - Elasticsearch/OpenSearch clusters
  - Splunk instances
  - DataDog, New Relic, Grafana Cloud

- **Data Management**:
  - Batch and streaming modes
  - Data format conversion (JSON, Parquet, Avro, CSV)
  - Compression options (gzip, snappy, zstd)
  - Partitioning strategies
  - Schema management
  - Data retention policies

- **Reliability Features**:
  - Dead letter queue support
  - Circuit breaker patterns
  - Automatic retries with exponential backoff
  - Connection pooling
  - Health checks and monitoring
  - Automatic failover to backup destinations
  - Data buffering and queuing

- **Security & Compliance**:
  - End-to-end encryption
  - Authentication mechanisms (OAuth2, API keys, mTLS, IAM roles)
  - Data masking and PII redaction
  - Audit logging for data transfers
  - Compliance metadata tagging
  - Data residency controls

**Integration with Pipelines:**
- Reference remote destinations in pipeline outputs
- Share destinations across multiple pipelines
- Conditional routing based on data attributes
- Load balancing across multiple instances
- Data replication and fan-out patterns


### Community Feedback

We welcome community input on these upcoming features. Please share your use cases and requirements through:
- GitHub Issues for feature requests [open an issue](https://github.com/openobserve/o2-k8s-operator/issues)
- Community forums for discussions [Start the conversation →](https://short.openobserve.ai/community)

## Summary

The OpenObserve Kubernetes Operator provides a robust, enterprise-ready solution for managing observability configurations at scale. With its comprehensive feature set, it enables teams to:

- Implement GitOps workflows for observability
- Maintain consistency across environments
- Automate operational tasks with alerts, pipelines, and functions
- Ensure security and compliance
- Scale observability management efficiently
- Transform and enrich data with VRL functions

Whether you're managing a single OpenObserve instance or orchestrating a complex multi-environment setup, the operator provides the tools and capabilities needed for success.