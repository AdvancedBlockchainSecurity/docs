# Vault Setup Quick Reference

> **Quick reference for initializing Vault in local development**

## TL;DR

```bash
# After starting Minikube or when Vault restarts
/Users/pwner/Git/ABS/scripts/init-vault-local.sh

# Verify secrets are syncing
kubectl get externalsecrets -A
```

## When to Run

| Scenario | Need to Run? | Why |
|----------|--------------|-----|
| Fresh Minikube start | ✅ Yes | Vault uses in-memory storage |
| Vault pod restart | ✅ Yes | Data lost on restart |
| Service deployment | ❌ No | External Secrets auto-sync |
| Code changes | ❌ No | Secrets unchanged |
| Daily development | ❌ No | Secrets persist while Vault runs |

## Quick Checks

### Is Vault Running?
```bash
kubectl get pod vault-0 -n vault-local
# Should show: Running
```

### Are Secrets Syncing?
```bash
kubectl get externalsecrets -A
# STATUS should be: SecretSynced
# READY should be: True
```

### Are Services Healthy?
```bash
kubectl get pods -A | grep -E "(api-service|tool-integration|data-service)" | grep -v Completed
# All should show: Running
```

## Troubleshooting

### External Secrets Failing
**Symptom**: `SecretSyncedError` status
**Fix**:
```bash
# Re-initialize Vault
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

### API Server Thrashing
**Symptom**: kubectl commands slow/timing out
**Fix**:
```bash
# Restart kubelet
minikube ssh "sudo systemctl restart kubelet"

# Re-initialize Vault after API server recovers
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

## Full Documentation

For detailed information, see:
- [Vault Initialization Guide](/Users/pwner/Git/ABS/blocksecops-docs/local-development/vault-initialization.md)
- [Production vs Local Differences](/Users/pwner/Git/ABS/blocksecops-docs/local-development/production-differences.md)
