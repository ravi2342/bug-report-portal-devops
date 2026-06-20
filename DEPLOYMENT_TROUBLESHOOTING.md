# Kubernetes Deployment Troubleshooting

## Issue: Service Cannot Be Modified

### Symptom
```
The Service "postgres" is invalid: spec.clusterIPs[0]: Invalid value: ["None"]: may not change once set
```

### Root Cause
Kubernetes **Services have immutable fields**. Once a Service is created with a specific `clusterIP`, you cannot change it to a different value (including making it headless with `clusterIP: None`).

**Timeline:**
1. Build #80: Created Service with `clusterIP: <some-ip>` (old postgres Deployment setup)
2. Build #82: Tried to apply Service with `clusterIP: None` (new StatefulSet setup)
3. **Conflict**: Kubernetes rejects the change → deployment fails

### Manual Fix (One-time)
```bash
# Delete the old Service
kubectl delete service postgres -n bug-report-portal-dev

# Next Jenkins run will create the new Service
```

## Immutable Kubernetes Fields

### Services
- `spec.clusterIP` - Cannot change once set
- `spec.clusterIPs` - Cannot change once set
- `spec.ipFamilies` - Cannot change once set
- `spec.type` - Cannot change from ClusterIP → Headless

### StatefulSets
- `spec.serviceName` - Cannot change once set
- `spec.selector` - Cannot change once set

### Deployments
- `spec.selector` - Cannot change once set

## Prevention Strategy

**When migrating K8s resources:**
1. Use `kubectl delete <resource-type> <name> --ignore-not-found` to clean conflicting resources
2. Add a 2-3 second sleep between delete and apply
3. Automate cleanup in CI/CD pipeline instead of manual intervention

## Related Issues
- **PostgreSQL Deployment → StatefulSet**: Required cleanup of old Deployment + Service
- **Service type changes**: Requires delete + recreate
- **Selector label changes**: Requires delete + recreate for most resources

## Best Practices

### For Major Architecture Changes
```bash
# Option 1: Clean namespace and redeploy (loses data)
kubectl delete namespace bug-report-portal-dev
kubectl apply -k .

# Option 2: Selective cleanup (preserves PVCs and data)
kubectl delete deployment,service --all -n bug-report-portal-dev
sleep 3
kubectl apply -k .
```

### For Testing New Features
Always use feature branches with `DEVOPS_BRANCH` parameter:
```
Jenkins Build with Parameters:
- DEVOPS_BRANCH: feature/postgres-statefulset
- DO_DEPLOY: true
```

This tests K8s changes before merging to master and avoids production issues.
