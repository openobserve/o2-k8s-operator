# OpenObserve Alert Template Samples

This directory contains example alert template configurations for the OpenObserve Kubernetes Operator. Alert templates define how alert notifications are formatted when sent to various destinations like Slack, email, PagerDuty, and other webhook services.

## Overview

The OpenObserve AlertTemplate CRD (`OpenObserveAlertTemplate`) allows you to create reusable notification templates that format alert data for different communication channels. These templates support dynamic variable substitution and can be referenced by multiple alerts through destinations.

## Why Use Alert Templates?

- **Consistency**: Maintain uniform notification formats across all alerts
- **Reusability**: Define once, use across multiple alerts
- **Customization**: Tailor messages for different channels (Slack, email, PagerDuty)
- **Dynamic Content**: Use variables to include alert-specific information
- **Branding**: Include organization-specific formatting and styling

## Prerequisites

Before using these samples:

1. **Deploy the OpenObserve Operator**
   ```bash
   ./deploy.sh
   ```

2. **Configure OpenObserve Connection**
   Create an OpenObserveConfig resource:
   ```bash
   kubectl apply -f configs/dev/o2dev-config.yaml
   ```

## Sample Files

| File | Type | Description | Use Case |
|------|------|-------------|-----------|
| `email-html-alert-template.yaml` | Email | Rich HTML email notification template | Send formatted email alerts with tables and styling |
| `email-text-alert-template.yaml` | Email | Plain text email notification template | Send simple text-based email alerts |
| `http-alert-template.yaml` | HTTP | Generic HTTP webhook template | Standard JSON payload for custom webhooks |
| `http-pagerduty-webhook-template.yaml` | HTTP | PagerDuty incident creation template | Create PagerDuty incidents with proper formatting |
| `http-slack-webhook-template.yaml` | HTTP | Slack notification template | Send rich Slack messages with attachments and fields |

## Template Types

### 1. Email Templates (`type: email`)

Used for email notifications with HTML formatting support.

**Features:**
- HTML/CSS styling
- Tables and structured layouts
- Rich text formatting
- Embedded links and buttons

**Example Structure:**
```yaml
type: email
title: "[{severity}] Alert: {alert_name}"  # Email subject
body: |
  <!DOCTYPE html>
  <html>
    <body>
      <h2>Alert: {alert_name}</h2>
      <p>Severity: {severity}</p>
      <!-- HTML content -->
    </body>
  </html>
```

### 2. HTTP Templates (`type: http`)

Used for webhook notifications including Slack, PagerDuty, Microsoft Teams, and custom endpoints.

**Features:**
- JSON payload formatting
- Service-specific structures
- Nested object support
- Array handling

**Example Structure:**
```yaml
type: http
title: "Alert: {alert_name}"
body: |
  {
    "alert": "{alert_name}",
    "severity": "{severity}",
    "timestamp": "{triggered_at}"
  }
```

## Available Variables

Templates support dynamic variable substitution using `{variable_name}` syntax:

### Core Variables
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{alert_name}` | Name of the triggered alert | "high-error-rate-alert" |
| `{alert_id}` | Unique alert identifier | "alert-123456" |
| `{alert_description}` | Alert description text | "Error rate exceeded threshold" |
| `{severity}` | Alert severity level | "critical", "warning", "info" |
| `{org_name}` | Organization name | "production-org" |
| `{stream_name}` | Source stream name | "application-logs" |
| `{stream_type}` | Type of stream | "logs", "metrics", "traces" |

### Time Variables
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{triggered_at}` | When alert was triggered | "2024-01-15T10:30:00Z" |
| `{timestamp}` | Current timestamp | "2024-01-15T10:30:00Z" |
| `{start_time}` | Alert evaluation start time | "2024-01-15T10:25:00Z" |
| `{end_time}` | Alert evaluation end time | "2024-01-15T10:30:00Z" |

### Condition Variables
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{threshold}` | Configured threshold value | "100" |
| `{actual_value}` | Actual value that triggered alert | "150" |
| `{operator}` | Comparison operator | ">=", "<=", "=" |
| `{condition}` | Full condition expression | "count >= 100" |

### Custom Variables
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{env}` | Environment | "production", "staging" |
| `{host}` | Host/server name | "server-01.example.com" |
| `{service}` | Service name | "payment-service" |
| `{region}` | Geographic region | "us-east-1" |
| `{dashboard_id}` | Dashboard identifier | "dash-123" |
| `{error_count}` | Error count | "150" |
| `{message}` | Custom message | "Custom alert message" |

## Usage Examples

### Deploy a Single Template

```bash
# Deploy Slack notification template
kubectl apply -f samples/alerttemplates/http-slack-webhook-template.yaml

# Verify template creation
kubectl get openobservealerttemplates -n o2operator
```

### Deploy All Templates

```bash
kubectl apply -f samples/alerttemplates/
```

### Reference Template in Destination

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveDestination
metadata:
  name: slack-destination
spec:
  type: http
  template: "slack-webhook-notification"  # Reference template by name
  url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## Creating Custom Templates

### Slack Template Example

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveAlertTemplate
metadata:
  name: custom-slack-template
spec:
  configRef:
    name: openobserve-main

  name: "custom-slack"
  type: http
  title: "Slack Alert"

  body: |
    {
      "blocks": [
        {
          "type": "header",
          "text": {
            "type": "plain_text",
            "text": "🚨 {alert_name}"
          }
        },
        {
          "type": "section",
          "fields": [
            {
              "type": "mrkdwn",
              "text": "*Severity:*\n{severity}"
            },
            {
              "type": "mrkdwn",
              "text": "*Time:*\n{triggered_at}"
            }
          ]
        }
      ]
    }
```

### Email Template Example

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveAlertTemplate
metadata:
  name: custom-email-template
spec:
  configRef:
    name: openobserve-main

  name: "custom-email"
  type: email
  title: "Alert: {alert_name} [{severity}]"

  body: |
    <html>
      <body style="font-family: Arial;">
        <div style="background: #f44336; color: white; padding: 10px;">
          <h2>{alert_name}</h2>
        </div>
        <div style="padding: 20px;">
          <p><strong>Description:</strong> {alert_description}</p>
          <p><strong>Time:</strong> {triggered_at}</p>
          <p><strong>Severity:</strong> {severity}</p>
        </div>
      </body>
    </html>
```

### PagerDuty Template Example

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveAlertTemplate
metadata:
  name: pagerduty-template
spec:
  configRef:
    name: openobserve-main

  name: "pagerduty-incident"
  type: http
  title: "PagerDuty Alert"

  body: |
    {
      "routing_key": "YOUR_ROUTING_KEY",
      "event_action": "trigger",
      "dedup_key": "{alert_id}",
      "payload": {
        "summary": "{alert_name}: {alert_description}",
        "severity": "{severity}",
        "source": "{stream_name}",
        "timestamp": "{triggered_at}",
        "custom_details": {
          "alert_id": "{alert_id}",
          "organization": "{org_name}",
          "threshold": "{threshold}",
          "actual_value": "{actual_value}"
        }
      }
    }
```

## Service-Specific Formatting

### Slack
- Use Block Kit for rich formatting
- Support for attachments and interactive elements
- Color coding based on severity
- Threading support with `thread_ts`

### Microsoft Teams
- Adaptive Cards format
- Action buttons
- Facts sections
- Hero images

### PagerDuty
- Incident creation with routing keys
- Deduplication keys
- Custom details
- Severity mapping

### Email
- Full HTML/CSS support
- Responsive design
- Tables and charts
- Call-to-action buttons

## Best Practices

1. **Use Descriptive Names**: Template names should indicate their purpose and destination
2. **Include Context**: Always include key information like alert name, time, and severity
3. **Format for Readability**: Use appropriate formatting (HTML for email, JSON for webhooks)
4. **Test Variables**: Ensure all referenced variables are available in your alerts
5. **Version Templates**: Keep different versions for testing and production
6. **Document Custom Variables**: Document any custom variables your templates expect
7. **Handle Missing Variables**: Consider default values for optional variables
8. **Escape Special Characters**: Properly escape JSON/HTML special characters

## Template Validation

Before deploying templates:

1. **JSON Validation** (for HTTP templates):
   ```bash
   # Extract and validate JSON from template
   yq eval '.spec.body' http-slack-webhook-template.yaml | jq .
   ```

2. **HTML Validation** (for email templates):
   ```bash
   # Check HTML structure
   yq eval '.spec.body' email-alert-template.yaml > temp.html
   # Open in browser to preview
   ```

3. **Variable Check**:
   - Ensure all variables used are documented
   - Test with sample data substitution

## Troubleshooting

### Template Not Found
- Verify template name matches exactly
- Check template is in the same organization
- Ensure template is created before destination

### Formatting Issues
- Validate JSON syntax for HTTP templates
- Check HTML validity for email templates
- Escape special characters properly

### Variable Not Substituted
- Verify variable name is correct (case-sensitive)
- Check if variable is available in alert context
- Review OpenObserve logs for substitution errors

## Integration with Destinations

Templates are used by destinations. See the [Destinations README](../destinations/README.md) for how to create destinations that reference these templates.

## Additional Resources

- [OpenObserve Alert Documentation](https://openobserve.ai/docs/alerts)
- [Alert Samples](../alerts/README.md)
- [Destination Configuration](../destinations/README.md)
- [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)

## Contributing

To add new alert template samples:
1. Create a YAML file following the naming convention
2. Include comprehensive comments
3. Test the template with actual alerts
4. Document any custom variables used
5. Update this README with the new template

For questions or issues, please [open an issue](https://github.com/openobserve/o2-k8s-operator/issues) on GitHub.