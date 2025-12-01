
## Troubleshooting

### Check Operator Status
```bash
# View operator pod status
kubectl get pods -n o2operator

# Check operator logs
kubectl logs -n o2operator deployment/openobserve-operator

# Follow logs in real-time
kubectl logs -f -n o2operator deployment/openobserve-operator
```

### Verify Installation
```bash
# Check CRDs
kubectl get crds | grep openobserve

# Check webhook
kubectl get validatingwebhookconfiguration openobserve-validating-webhook

# View all OpenObserve resources
kubectl get openobserveconfigs,openobservealerts,openobservepipelines --all-namespaces
```

### Access Metrics
```bash
# Port-forward to metrics service
kubectl port-forward -n o2operator svc/openobserve-operator-metrics 8080:8080

# View metrics
curl http://localhost:8080/metrics
```

### Common Issues

1. **Stuck uninstall**: The deploy script automatically removes finalizers during uninstall
2. **Webhook certificate issues**: Use `--skip-certs` flag if having certificate problems
3. **Config not ready errors**: Ensure OpenObserveConfig has valid credentials and endpoint
