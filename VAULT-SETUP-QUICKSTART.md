# Vault Setup Quick Reference

> **Quick reference for initializing Vault in local development**

## TL;DR

```bash
# Initial setup only (first time or after PVC deletion)
/Users/pwner/Git/ABS/scripts/init-vault-local.sh

# Verify secrets are syncing
kubectl get externalsecrets -A
```

## When to Run

| Scenario | Need to Run? | Why |
|----------|--------------|-----|
| First-time cluster setup | ✅ Yes | Initialize Vault and seed secrets |
| PVC deleted/recreated | ✅ Yes | Vault data was deleted |
| Minikube restart | ❌ No | Secrets persist on PVC, auto-unseals |
| Vault pod restart | ❌ No | Auto-unseals using stored key |
| Service deployment | ❌ No | External Secrets auto-sync |
| Code changes | ❌ No | Secrets unchanged |
| Daily development | ❌ No | Secrets persist while cluster exists |

## Vault Storage Architecture

**Local development uses persistent file storage:**

| Component | Location | Purpose |
|-----------|----------|---------|
| Vault data | `/vault/data` (PVC) | Secrets, policies, configuration |
| Init file | `/vault/data/.vault-init.json` | Unseal key and root token |
| Config | `/vault/config/vault.hcl` | Server configuration |

**Auto-unseal behavior:**
- Init container checks if Vault is initialized
- If initialized, unseals using stored key from PVC
- Main container starts Vault server and unseals again
- No manual intervention required

## Quick Checks

### Is Vault Running and Unsealed?
```bash
kubectl exec -n vault-local vault-0 -- vault status
# Should show: Sealed = false, Storage Type = file
```

### Are Secrets Syncing?
```bash
kubectl get externalsecrets -A
# STATUS should be: SecretSynced
# READY should be: True
```

### Are Services Healthy?
```bash
kubectl get pods -A | grep -E "(api-service|orchestration|tool-integration)" | grep -v Completed
# All should show: Running
```

## Troubleshooting

### External Secrets Failing
**Symptom**: `SecretSyncedError` status

**Check SecretStore:**
```bash
kubectl describe secretstore vault-backend -n <namespace>
```

**Possible causes:**
1. Vault role doesn't exist - create role for the service
2. Vault is sealed - check `vault status`
3. Secrets not in Vault - run `init-vault-local.sh`

**Fix:**
```bash
# Get root token
ROOT_TOKEN=$(kubectl exec -n vault-local vault-0 -- cat /vault/data/.vault-init.json | awk -F'"' '/"root_token"/{print $4}')

# Create role for service (if missing)
kubectl exec -n vault-local vault-0 -- env VAULT_TOKEN="$ROOT_TOKEN" vault write auth/kubernetes/role/<service-name> \
  bound_service_account_names="<service-name>" \
  bound_service_account_namespaces="<namespace>" \
  policies=external-secrets \
  ttl=1h

# Re-seed secrets if needed
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

### Vault Sealed After Restart
**Symptom**: `Sealed = true` in vault status

This should not happen with auto-unseal, but if it does:
```bash
# Get unseal key from init file
kubectl exec -n vault-local vault-0 -- cat /vault/data/.vault-init.json

# Manually unseal
kubectl exec -n vault-local vault-0 -- vault operator unseal <unseal_key>
```

### API Server Thrashing
**Symptom**: kubectl commands slow/timing out
**Fix**:
```bash
# Restart kubelet
minikube ssh "sudo systemctl restart kubelet"

# Wait for API server to recover
kubectl get nodes
```

## Full Documentation

For detailed information, see:
- [Secrets Management Standards](/Users/pwner/Git/ABS/docs/standards/secrets-management.md)
- [Vault Initialization Guide](/Users/pwner/Git/ABS/blocksecops-docs/local-development/vault-initialization.md)
- [Production vs Local Differences](/Users/pwner/Git/ABS/blocksecops-docs/local-development/production-differences.md)
