#!/bin/bash
# BlockSecOps Go-Live Audit: Kubernetes Security Checks (Section 7)
# Run against target cluster before production launch
set -euo pipefail

PASS=0
FAIL=0
WARN=0

NAMESPACES=(
  api-service-local
  orchestration-local
  tool-integration-local
  dashboard-local
  data-service-local
  intelligence-engine-local
  notification-local
  contract-parser-local
)

# For GCP production, override with:
# NAMESPACES=(api-service orchestration tool-integration dashboard data-service intelligence-engine notification contract-parser)

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $name"
    ((PASS++))
  else
    echo "  FAIL: $name (expected=$expected, got=$actual)"
    ((FAIL++))
  fi
}

warn() {
  local name="$1" msg="$2"
  echo "  WARN: $name ($msg)"
  ((WARN++))
}

echo "=============================================="
echo " BlockSecOps K8s Security Audit"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="

# --- 7.1 Pod Security Contexts ---
echo ""
echo "=== 7.1 Pod Security: runAsNonRoot, runAsUser ==="

for ns in "${NAMESPACES[@]}"; do
  DEPLOY=$(kubectl get deployment -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$DEPLOY" ]; then
    warn "$ns" "no deployment found"
    continue
  fi

  RUN_AS_NON_ROOT=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null)
  RUN_AS_USER=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.securityContext.runAsUser}' 2>/dev/null)

  check "$ns/$DEPLOY runAsNonRoot" "true" "$RUN_AS_NON_ROOT"
  check "$ns/$DEPLOY runAsUser" "1000" "$RUN_AS_USER"
done

# --- 7.2 Container Security Contexts ---
echo ""
echo "=== 7.2 Container Security: readOnlyRootFilesystem, drop ALL ==="

for ns in "${NAMESPACES[@]}"; do
  DEPLOY=$(kubectl get deployment -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$DEPLOY" ]; then continue; fi

  READ_ONLY=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
  PRIV_ESC=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)

  check "$ns/$DEPLOY readOnlyRootFilesystem" "true" "$READ_ONLY"
  check "$ns/$DEPLOY allowPrivilegeEscalation" "false" "$PRIV_ESC"
done

# --- 7.3 Seccomp Profile ---
echo ""
echo "=== 7.3 Seccomp Profile: RuntimeDefault ==="

for ns in "${NAMESPACES[@]}"; do
  DEPLOY=$(kubectl get deployment -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$DEPLOY" ]; then continue; fi

  SECCOMP=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null)
  check "$ns/$DEPLOY seccompProfile" "RuntimeDefault" "$SECCOMP"
done

# --- 7.4 NetworkPolicies ---
echo ""
echo "=== 7.4 NetworkPolicies: default deny + allow rules ==="

for ns in "${NAMESPACES[@]}"; do
  NP_COUNT=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "$NP_COUNT" -ge 1 ]; then
    echo "  PASS: $ns has $NP_COUNT NetworkPolicy(ies)"
    ((PASS++))
  else
    echo "  FAIL: $ns has 0 NetworkPolicies"
    ((FAIL++))
  fi
done

# --- 7.6 revisionHistoryLimit ---
echo ""
echo "=== 7.6 revisionHistoryLimit: 3 ==="

for ns in "${NAMESPACES[@]}"; do
  DEPLOY=$(kubectl get deployment -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$DEPLOY" ]; then continue; fi

  LIMIT=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.revisionHistoryLimit}' 2>/dev/null)
  check "$ns/$DEPLOY revisionHistoryLimit" "3" "$LIMIT"
done

# --- 7.9 Resource Limits ---
echo ""
echo "=== 7.9 Resource Limits: CPU/memory set ==="

for ns in "${NAMESPACES[@]}"; do
  DEPLOY=$(kubectl get deployment -n "$ns" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$DEPLOY" ]; then continue; fi

  CPU_LIMIT=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
  MEM_LIMIT=$(kubectl get deployment -n "$ns" "$DEPLOY" -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)

  if [ -n "$CPU_LIMIT" ] && [ -n "$MEM_LIMIT" ]; then
    echo "  PASS: $ns/$DEPLOY limits: cpu=$CPU_LIMIT mem=$MEM_LIMIT"
    ((PASS++))
  else
    echo "  FAIL: $ns/$DEPLOY missing limits (cpu=$CPU_LIMIT, mem=$MEM_LIMIT)"
    ((FAIL++))
  fi
done

# --- 7.10 No :latest tags ---
echo ""
echo "=== 7.10 Image Tags: no :latest ==="

LATEST_COUNT=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' 2>/dev/null | grep ":latest" | wc -l | tr -d ' ')
if [ "$LATEST_COUNT" -eq 0 ]; then
  echo "  PASS: No :latest image tags found"
  ((PASS++))
else
  echo "  FAIL: $LATEST_COUNT containers using :latest tag"
  ((FAIL++))
  kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.containers[*].image}{"\n"}{end}' 2>/dev/null | grep ":latest"
fi

# --- 7.11 No plaintext secrets in manifests ---
echo ""
echo "=== 7.11 Secrets: no plaintext in Git ==="

if [ -d "blocksecops-gcp-infrastructure/k8s" ]; then
  SECRET_HITS=$(grep -rl "password:\|secret:\|api_key:\|token:" \
    blocksecops-gcp-infrastructure/k8s/ \
    --include="*.yaml" --include="*.yml" 2>/dev/null | \
    grep -v "ExternalSecret\|SecretStore\|kind: Secret" | wc -l | tr -d ' ')
  if [ "$SECRET_HITS" -eq 0 ]; then
    echo "  PASS: No plaintext secrets in k8s manifests"
    ((PASS++))
  else
    echo "  WARN: $SECRET_HITS files may contain secrets (review manually)"
    ((WARN++))
  fi
else
  warn "Secrets check" "blocksecops-gcp-infrastructure/k8s not found"
fi

# --- Summary ---
echo ""
echo "=============================================="
echo " SUMMARY"
echo "=============================================="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  Result: ALL CHECKS PASSED"
  exit 0
else
  echo "  Result: $FAIL CHECKS FAILED"
  exit 1
fi
