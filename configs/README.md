# OpenObserve Configuration Examples

This directory contains example configurations for connecting to OpenObserve using different authentication methods.

## Authentication Types

OpenObserve supports two types of authentication, both using HTTP Basic Authentication:

### 1. Service Account Authentication
- Uses a service account token for authentication
- Token acts as the password in HTTP Basic Auth
- Identified by `key: token` in the `credentialsSecretRef`
- Limited permissions (cannot access report folders)
- Ideal for automated operations and CI/CD pipelines

### 2. User Account Authentication
- Uses username and password for authentication
- Standard HTTP Basic Auth
- Identified by any key other than "token" (e.g., "password", "credentials", or empty)
- Full administrative permissions
- Suitable for human operators and administrative tasks

## File Descriptions

| File | Description | Authentication Type |
|------|-------------|-------------------|
| `service-account-example.yaml` | Example configuration for service account authentication | Service Account |
| `user-account-example.yaml` | Example configuration for user account authentication | User Account |

## Creating Secrets

### For Service Accounts

```bash
# Create secret with username and token
kubectl create secret generic o2-service-account \
  --namespace=o2operator \
  --from-literal=username='svc_account@example.com' \
  --from-literal=token='your-service-token-here'
```

### For User Accounts

```bash
# Create secret with username and password
kubectl create secret generic o2-user-account \
  --namespace=o2operator \
  --from-literal=username='user@example.com' \
  --from-literal=password='your-password-here'
```

## Using the Configuration

Once you've created the OpenObserveConfig, you can reference it in your resources:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveAlert
metadata:
  name: my-alert
spec:
  configRef:
    name: openobserve-service-account  # or openobserve-user-account
    namespace: o2operator
  # ... rest of alert configuration
```

## Important Notes

### Service Account Limitations
Service accounts have the following limitations:
- Cannot access report folders (returns 403 Forbidden)
- Must specify folder for alert operations
- Cannot use folder name lookup endpoints
- Limited to programmatic access within assigned folders

### User Account Capabilities
User accounts have full access:
- Can manage alerts, dashboards, and reports
- Can perform administrative operations
- Can access resources across folders
- Can lookup folders by name

## Choosing the Right Authentication

| Use Case | Recommended Type | Reason |
|----------|-----------------|---------|
| CI/CD Pipelines | Service Account | Limited permissions, token-based |
| Automated Alert Management | Service Account | Programmatic access |
| Dashboard Administration | User Account | Requires full permissions |
| Report Management | User Account | Service accounts cannot access reports |
| Development/Testing | User Account | Full access for exploration |

## Troubleshooting

### Common Issues

1. **401 Unauthorized**
   - Verify username and token/password are correct
   - Check that the secret exists and contains the right keys
   - Ensure the OpenObserve endpoint is reachable

2. **403 Forbidden (Service Accounts)**
   - This is expected for report folders
   - Ensure you're specifying folders for alert operations
   - Consider using a user account if you need full access

3. **Secret Not Found**
   - Verify the secret name and namespace match the configRef
   - Ensure the secret is created before the OpenObserveConfig

### Debugging Authentication

To check which type of authentication is being used:

```bash
# Check the OpenObserveConfig
kubectl get openobserveconfig -o yaml

# Look for the credentialsSecretRef.key field:
# - key: "token" → Service Account
# - key: anything else → User Account

# Check the secret contents (be careful with sensitive data)
kubectl get secret o2-credentials -o yaml | base64 -d
```

## Security Best Practices

1. **Use Service Accounts for Automation**: Limit permissions for automated processes
2. **Rotate Credentials Regularly**: Update tokens and passwords periodically
3. **Use Separate Configs**: Don't share configs between environments
4. **Limit Secret Access**: Use RBAC to control who can read secrets
5. **Monitor Usage**: Track which accounts are accessing OpenObserve