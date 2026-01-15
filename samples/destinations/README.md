# OpenObserve Destinations

This directory contains sample configurations for OpenObserve destinations, which can be either **Alert Destinations** or **Pipeline Destinations**.

## Destination Types

### Alert Destinations
Alert destinations are used to send alerts to various endpoints. They:
- **Require** a template reference
- Do NOT have a `destinationTypeName` field (or it's empty)
- Support types: `http`, `email`

### Pipeline Destinations
Pipeline destinations are used to send pipeline data to external systems. They:
- Do NOT use templates
- **Require** a `destinationTypeName` field
- Are always of type `http`
- Support destination types: `custom`, `openobserve`, `splunk`, `newrelic`, `elasticsearch`, `dynatrace`, `datadog`

## Output Format Requirements

Each pipeline destination type has specific output format requirements:

| Destination Type | Required Output Format | Notes |
|-----------------|------------------------|-------|
| `openobserve` | `json` | JSON format only |
| `splunk` | `nestedevent` | Splunk HEC event format |
| `newrelic` | `json` | JSON format only |
| `elasticsearch` | `esbulk` | Elasticsearch bulk format |
| `dynatrace` | `json` | JSON format only |
| `datadog` | `json` | JSON format only |
| `custom` | `json` or `nestedevent` | Flexible format options |

## Sample Files

### Alert Destinations
- `http-alert-destination.yaml` - HTTP webhook for alerts
- `email-alert-destination.yaml` - Email notifications for alerts

### Pipeline Destinations
- `pipeline-custom-destination.yaml` - Send data to custom endpoints
- `pipeline-datadog-destination.yaml` - Send data to Datadog
- `pipeline-dynatrace-destination.yaml` - Send data to Dynatrace
- `pipeline-elasticsearch-destination.yaml` - Send data to Elasticsearch
- `pipeline-newrelic-destination.yaml` - Send data to New Relic
- `pipeline-openobserve-desntination.yaml` - Send data to another OpenObserve instance
- `pipeline-splunk-destination.yaml` - Send data to Splunk HEC

## Validation Rules

The webhook validator enforces the following rules:

1. **Organization must exist** - The specified org must be accessible
2. **Template validation** (Alert destinations only) - Template must exist in the same organization
3. **Output format validation** (Pipeline destinations) - Must match the required format for each destination type
4. **Header validation** - Specific headers required for certain destination types:
   - Splunk: `Authorization` header starting with "Splunk "
   - Datadog: `DD-API-KEY` header
   - Dynatrace: `Authorization` header starting with "Api-Token "
   - New Relic: `Api-Key` header
   - OpenObserve: `Authorization` header starting with "Basic "
5. **Metadata validation** - Required metadata fields for specific destination types:
   - Datadog: `ddsource` and `ddtags` are **mandatory** in metadata

## Usage Examples

### Creating an Alert Destination
```bash
kubectl apply -f http-alert-destination.yaml
```

### Creating a Pipeline Destination
```bash
kubectl apply -f pipeline-splunk-destination.yaml
```

### Listing All Destinations
```bash
kubectl get openobservedestinations -n o2operator
```

### Describing a Destination
```bash
kubectl describe openobservedestination webhook-alert-dest -n o2operator
```

## Troubleshooting

Common validation errors and solutions:

1. **"Organization 'X' does not exist"** - Ensure the organization exists in OpenObserve or use the correct org name
2. **"Alert template 'Y' does not exist in organization 'X'"** - Create the template first using OpenObserveAlertTemplate resource
3. **"outputFormat must be 'Z'"** - Check the output format requirements table above
4. **"Email destinations require SMTP to be configured"** - Configure SMTP in your OpenObserve instance