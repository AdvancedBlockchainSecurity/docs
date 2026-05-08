# Playbook: Scanner Pipeline Troubleshooting

**Version:** 1.5.0
**Last Updated:** 2026-05-03

## Overview

This playbook covers diagnosing and fixing issues when scanner Jobs complete but produce 0 findings or fail to deliver results. Based on real-world fixes applied to 5 of 6 scanners in February 2026.

---

## Quick Diagnosis

```bash
# 1. Check if scanner Job completed
kubectl get jobs -n tool-integration-local -l scanner=<scanner-name>

# 2. Check scanner pod logs (before result collector cleans up)
kubectl logs -n tool-integration-local -l job-name=scan-<scanner>-<scan-id-prefix>

# 3. Check tool-integration logs for callback receipt
kubectl logs -n tool-integration-local deployment/tool-integration --tail=100 | grep "<scan-id>"

# 4. Check if results were forwarded to API service
kubectl logs -n tool-integration-local deployment/tool-integration --tail=100 | grep "POST.*results"
```

---

## Check Scan Error Message (v0.29.67+)

Failed scans now include an `error_message` field in the API response:

```bash
# Check error message via API
curl -sk https://app.0xapogee.com/api/v1/scans/{scan_id} \
  -H "Authorization: Bearer $TOKEN" | jq '{status, error_message}'
```

Common error messages:
- `"Scanners ['halmos'] require a project..."` — Scanner needs a multi-file project, not a single file
- `"Failed to trigger any scanners..."` — Tool-integration service is down
- `"Scanner triggering aborted after N failures"` — Multiple scanners failed to trigger
- `null` (on failed scan) — Legacy scan from before v0.29.67

---

## Common Issues

### Issue 1: Scanner Pod Exits with 0 Findings (UID Mismatch)

**Symptoms:**
- Scanner Job shows `status: completed`
- Pod logs show scanner ran but found nothing
- `scanner_results: null` in API response

**Root Cause:** K8s security context forces UID 1000, but Dockerfile creates user with UID 1001. Scanner can't write to directories owned by UID 1001.

**Diagnosis:**
```bash
# Check Dockerfile UID
grep -E 'useradd|adduser' scanner-images/<scanner>/Dockerfile

# Check K8s security context
grep -A5 'security_context' src/scanners/kubernetes_job_manager.py
```

**Fix:**
```bash
# In Dockerfile, change UID to 1000:
RUN useradd -m -u 1000 scanner  # Was: useradd -m -u 1001 scanner

# Rebuild and push
docker build -t harbor.blocksecops.local/blocksecops/scanner-<name>:<new-version> .
docker push harbor.blocksecops.local/blocksecops/scanner-<name>:<new-version>
```

---

### Issue 2: Callback POST Fails (Alpine DNS)

**Symptoms:**
- Scanner completes and finds vulnerabilities
- Log shows `Failed to post results (HTTP 000)`
- Only affects Alpine-based images (solhint, others)

**Root Cause:** Alpine's musl libc sends A and AAAA DNS queries on the same socket. CoreDNS processes them sequentially, causing the second query to time out.

**Diagnosis:**
```bash
# Test DNS from Alpine pod
kubectl run dns-test --image=alpine --rm -it -- sh -c "
  apk add --no-cache curl
  curl -v http://tool-integration.tool-integration-local.svc.cluster.local.:8005/health
"
```

**Fix:** Applied in `kubernetes_job_manager.py`:
```python
# 1. Add dnsConfig with single-request-reopen
dns_config=client.V1PodDNSConfig(
    options=[client.V1PodDNSConfigOption(name="single-request-reopen")]
),

# 2. Use trailing dot on FQDN in callback URLs
value=f"http://tool-integration.{self.namespace}.svc.cluster.local.:8005"
```

---

### Issue 3: Solhint Returns 0 Findings (stdout Pollution)

**Symptoms:**
- Solhint runs but `Solhint output is not valid JSON`
- 0 findings despite contracts having lint issues

**Root Cause:** Solhint prints debug messages to stdout before JSON:
```
A new version of Solhint is available: 6.0.3
isPublicLike :>>  false
comments.length :>>  0
[{"line":3,"column":1,"severity":"Warning",...}]
```

**Fix:** In `solhint-scan`:
```bash
# Capture raw output, extract only JSON line
timeout "$SOLHINT_TIMEOUT" solhint ... > "$SOLHINT_RAW" 2>/tmp/solhint-stderr.log
grep '^\[' "$SOLHINT_RAW" > "$SOLHINT_OUTPUT"

# Filter out conclusion entry (null ruleId)
jq '[.[] | select(.ruleId != null) | ...]'
```

---

### Issue 4: Slither Can't Find solc (HOME Not Set / emptyDir Shadows)

**Symptoms:**
- `PermissionError: [Errno 13] Permission denied: '/.solc-select'`
- Slither fails during compilation step
- Scanner pod stuck downloading solc from soliditylang.org

**Root Cause:** Two related issues:
1. When K8s overrides the user via `runAsUser: 1000`, the HOME env var is not set. solc-select defaults to `$HOME/.solc-select/`, which becomes `/.solc-select/`.
2. KJM mounts an `emptyDir` at `/home/scanner` for `readOnlyRootFilesystem` compliance, which shadows any solc binaries baked into `~/.solc-select/` during Docker build.

**Fix (v0.3.8):**
1. Add `ENV HOME=/home/scanner` to Dockerfile before `USER scanner`
2. Pre-install solc versions to `/opt/solc-select/artifacts` (survives emptyDir mount)
3. Add runtime seed step in `run-slither.sh` to copy from `/opt` to `$HOME/.solc-select/`

**Current state:** 8 solc versions (0.8.13–0.8.28) pre-installed in all Solidity scanner images. Runtime seed completes in <1s.

**Applies to ALL Solidity scanners**, not just slither:
- **solc-select scanners** (slither, echidna, medusa): Pre-install to `/opt/solc-select/artifacts/`
- **Foundry scanners** (aderyn, soliditydefend, halmos, wake): Pre-install to `/opt/svm/` (Foundry uses `~/.svm/`, NOT `~/.solc-select/`)

---

### Issue 4b: Foundry Scanner Can't Compile (forge-std missing)

**Symptoms:**
- Scan completes with 0 vulnerabilities on Foundry projects
- Logs show `forge install foundry-rs/forge-std` failed
- `Warning: Could not install forge-std, continuing anyway...`

**Root Cause:** Foundry projects require forge-std library for compilation. Run scripts tried to clone from GitHub at runtime, which is blocked by NetworkPolicy.

**Fix:** Pre-install forge-std v1.9.6 at build time:
```dockerfile
RUN mkdir -p /opt/forge-std/lib/forge-std && \
    curl -sL https://github.com/foundry-rs/forge-std/archive/refs/tags/v1.9.6.tar.gz | \
    tar xz --strip-components=1 -C /opt/forge-std/lib/forge-std
```

Run scripts copy from `/opt/forge-std/lib/forge-std` to project `lib/` at container startup. Also set `offline = true` in foundry.toml to prevent any download attempts.

**Current state:** forge-std pre-installed in aderyn, slither, soliditydefend, halmos, wake images.

---

### Issue 4c: Scanner Callback Returns 403 Forbidden

**Symptoms:**
- Scanner pod completes successfully with findings
- Pod logs show `Failed to post results (HTTP 403): {"detail":"Invalid service token"}`
- Scan marked as completed with 0 vulnerabilities

**Root Cause:** Security audit (March 2026) added `X-Internal-Service-Token` authentication to the `/api/v1/scans/{scan_id}/results` callback endpoint. Scanner entrypoint scripts didn't include the token header.

**Fix (v0.5.36):**
1. KJM passes `INTERNAL_SERVICE_TOKEN` env var to scanner K8s Job pods
2. All 11 scanner entrypoint scripts include `-H "X-Internal-Service-Token: ${INTERNAL_SERVICE_TOKEN:-}"` in callback curl POST

**Diagnosis:**
```bash
# Check if callback is getting 403
kubectl logs -n tool-integration-prod deployment/tool-integration --since=10m | grep "403"
# If you see: POST /api/v1/scans/{id}/results HTTP/1.1 403 Forbidden
# → Scanner images need the auth header update
```

---

### Issue 4d: Multi-File Project Returns 0 Findings

**Symptoms:**
- Single-file contracts produce findings but multi-file projects produce 0
- Scanner entrypoint logs show files at `/contracts/src_Token.sol` instead of `/contracts/src/Token.sol`

**Root Cause:** ConfigMap keys flatten directory paths (slashes replaced with underscores). Scanner entrypoint scripts must reconstruct the directory structure before running analysis.

**Fix:** Scanner entrypoint scripts detect multi-file projects (presence of `foundry.toml`, `hardhat.config.js`, or `manifest.json`), copy to writable `/tmp/project`, and reconstruct directory structure:
```bash
for file in *.sol; do
    if [ -f "$file" ] && [[ "$file" == *_* ]]; then
        dir_part="${file%%_*}"
        file_part="${file#*_}"
        mkdir -p "$dir_part"
        mv "$file" "$dir_part/$file_part"
    fi
done
```

**Current state:** Multi-file support added to soliditydefend, semgrep, solhint, halmos, medusa, rustdefend, moccasin, vyper, wake. Slither and aderyn already had it.

---

### Issue 5: Scanner Reads Wrong Directory

**Symptoms:**
- Scanner runs but says "0 Solidity files found"
- Contracts are actually mounted at `/contracts`

**Root Cause:** Scanner entrypoint defaults to `/work` but K8s mounts contracts at `/contracts`.

**Fix:** Set `WORK_DIR=/contracts` in K8s Job environment:
```python
client.V1EnvVar(name="WORK_DIR", value="/contracts"),
```

---

### Issue 6: Semgrep Returns 0 Findings (No Internet)

**Symptoms:**
- Semgrep exits with code 7 or shows "No rules"
- Works locally but not in K8s cluster

**Root Cause:** Semgrep downloads rules from the Semgrep registry (p/smart-contracts, p/security-audit) at runtime. Air-gapped clusters can't reach the registry. The pre-cache approach (running semgrep during build) doesn't persist rules as files.

**Fix (applied in scanner-semgrep:0.3.5):** Download rules as local YAML files during Docker build:
```dockerfile
# Download rule packs as local YAML files for offline use
RUN curl -fsSL "https://semgrep.dev/c/p/smart-contracts" -o /rules/smart-contracts.yaml && \
    curl -fsSL "https://semgrep.dev/c/p/security-audit" -o /rules/security-audit.yaml

# Set ENV to use local files instead of registry
ENV SEMGREP_RULES="/rules/smart-contracts.yaml,/rules/security-audit.yaml"
ENV SEMGREP_SEND_METRICS=off
ENV SEMGREP_ENABLE_VERSION_CHECK=0
```

### Issue 7: Aderyn/Semgrep Callback Fails Intermittently

**Symptoms:** Scanner Job completes but no callback received by tool-integration. Occasional DNS resolution failures or connection timeouts.

**Root Cause:** The `curl` POST in the scanner entrypoint had no retry or timeout options. Transient DNS failures or K8s service routing delays cause a single-shot curl to fail.

**Fix (applied in scanner-aderyn:0.7.2 and scanner-semgrep:0.3.5):** Add curl resilience options:
```bash
curl -s -w "\n%{http_code}" -X POST "$CALLBACK_URL" \
    -H "Content-Type: application/json" \
    --connect-timeout 10 \
    --max-time 60 \
    --retry 3 \
    --retry-delay 2 \
    --retry-all-errors \
    -d @"$OUTPUT_FILE"
```

---

### Issue 10: Scanner Returns 0 Results Despite Completing (NetworkPolicy)

**Symptoms:**
- Scanner Jobs complete successfully (status: Completed)
- Scanner pod logs show analysis ran and found vulnerabilities
- Tool-integration receives NO callback (no POST logged)
- Database shows 0 vulnerabilities for the scan
- Other scans of the same contract previously had results

**Root Cause:** In namespaces with `default-deny-all` NetworkPolicy, scanner pods (label `app: scanner`) have no egress rule allowing them to POST results to tool-integration on port 8005. The `tool-integration-network-policy` only applies to pods with `app: tool-integration`, not scanner pods. Scanner pods can resolve DNS (via `allow-dns` policy) but cannot make HTTP connections.

**Diagnosis:**
```bash
# Check if scanner pods have egress NetworkPolicy
kubectl get networkpolicy -n tool-integration-<env> -o wide | grep scanner

# Verify scanner pod labels
kubectl get pods -n tool-integration-<env> -l app=scanner -o wide

# Check if tool-integration allows ingress from scanner pods
kubectl describe networkpolicy tool-integration-network-policy -n tool-integration-<env> | grep -A5 scanner

# Test connectivity from a scanner-labeled pod
kubectl run nettest --image=busybox --labels="app=scanner" -n tool-integration-<env> --rm -it -- \
  wget -qO- --timeout=5 http://tool-integration.tool-integration-<env>.svc.cluster.local.:8005/health || echo "BLOCKED"
```

**Fix (applied in v0.5.26):**
1. Added `k8s/base/scanner-network-policy.yaml` — grants scanner pods egress for DNS (port 53) and tool-integration callback (port 8005)
2. Added ingress rule to `tool-integration-network-policy` (base and all overlays) allowing traffic FROM `app: scanner` pods on port 8005
3. Both policies must exist: egress from scanner pods AND ingress to tool-integration from scanner pods

**Verification:**
```bash
# Confirm scanner NetworkPolicy exists
kubectl get networkpolicy scanner-network-policy -n tool-integration-<env>

# Confirm tool-integration accepts scanner ingress
kubectl describe networkpolicy tool-integration-network-policy -n tool-integration-<env> | grep -A3 "app: scanner"

# Run regression tests
pytest tests/regression/test_scanner_network_policy.py -v
```

**Prevention:** 10 regression tests in `tests/regression/test_scanner_network_policy.py` verify:
- Scanner NetworkPolicy exists and targets correct pods
- DNS and callback egress rules present
- Ingress from scanner pods allowed in base, GCP, and local overlays
- KJM pod template label matches NetworkPolicy selector
- CALLBACK_URL port matches NetworkPolicy allowed port

---

### Issue 11: Rust Scanner Fails with "failed to select a version" or "no matching package" (Vendored Crates)

**Symptoms:**
- trident or cargo-fuzz-solana scan completes (status=completed) but reports 0 findings or build errors in logs
- Logs show:
  ```
  error: failed to select a version for the requirement `anchor-lang = "^0.29.0"`
  location searched: directory source `/opt/cargo-fuzz-vendor` (which is replacing registry `crates-io`)
  note: perhaps a crate was updated and forgotten to be re-vendored?
  ```
  Or: `error: no matching package named 'XYZ' found`

**Root Cause:** Scanner pods cannot reach crates.io (NetworkPolicy egress allows only DNS + tool-integration callback). All required crates are pre-vendored at Docker build time into `/opt/cargo-vendor/` (trident) or `/opt/cargo-fuzz-vendor/` (cargo-fuzz-solana). If the user's `Cargo.toml` requires a crate version not in the vendored set, the offline build fails.

**Currently vendored:**
- **trident**: anchor-lang 0.30.1, anchor-spl 0.30.1, solana-program 1.18, solana-sdk 1.18, spl-token 4, spl-associated-token-account 3, borsh 1, thiserror 1
- **cargo-fuzz-solana**: same as trident **plus** anchor-lang 0.29.0, anchor-spl 0.29.0, solana-program 1.17, libfuzzer-sys 0.4, arbitrary 1

**Resolution:**
1. Verify the user's required crate is missing from the vendor: check the scanner image's `/opt/cargo-vendor/` (or `cargo-fuzz-vendor/`) directory listing
2. To add a crate to the vendored set: edit the skeleton `Cargo.toml` in the scanner's Dockerfile (`scanner-images/trident/Dockerfile` or `scanner-images/cargo-fuzz-solana/Dockerfile`), bump scanner image version, rebuild + push + redeploy
3. The wrapper handles the failure gracefully — returns `status=completed` with `vulnerabilities=[]` rather than crashing

**Diagnostic:**
```bash
# Inspect what's vendored in the scanner image
docker run --rm --entrypoint /bin/sh scanner-trident:0.4.0 \
  -c "ls /opt/cargo-vendor/ | head -30"

# Check scanner job logs for offline build errors
kubectl logs -n tool-integration-prod job/scan-trident-<scan_id> | grep -E "failed to select|no matching package|offline"
```

---

### Issue 15: Aderyn/Slither Foundry+OZ Silent-Pass (Resolved 2026-05-03; sweep extended to wake/echidna/medusa/soliditydefend 2026-05-04)

**Status: Resolved at scanner-aderyn:0.8.5 / scanner-slither:0.4.7 / scanner-wake:0.5.8 / scanner-echidna:0.5.4 / scanner-medusa:0.4.4 / scanner-soliditydefend:0.9.10**

**Symptoms (pre-fix):**
- Foundry project with `@openzeppelin/contracts/` imports scans to `vulnerabilities:[]`.
- `status` is `completed`, `error_message` is `null`.
- The same contract compiled locally by `forge build` shows issues. Re-scanning does not change the result.
- Originally surfaced for aderyn and slither. Static re-audit on 2026-05-04 swept the same fix into wake, echidna, medusa, and soliditydefend Foundry branches. The wake sweep introduced regression #192 — see Issue 16 below for the wake-specific follow-up.

**Diagnosis — confirm this is the OZ remapping gap:**

```bash
# 1. Retrieve the scan result and confirm empty findings with no error.
curl -sk https://app.0xapogee.com/api/v1/scans/<scan_id> \
  -H "Authorization: Bearer $TOKEN" | jq '{status, error_message, critical_count, high_count, medium_count, low_count}'
# Expected pattern: status=completed, error_message=null, all counts=0

# 2. Retrieve the contract and confirm it has OZ imports.
curl -sk https://app.0xapogee.com/api/v1/contracts/<contract_id> \
  -H "Authorization: Bearer $TOKEN" | jq '.framework'
# If framework=foundry, check source files for @openzeppelin/contracts/ imports.

# 3. Confirm the scanner image version is pre-fix.
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_ADERYN}'
# Pre-fix: ...scanner-aderyn:0.8.3 or earlier → fix not deployed
# Post-fix: ...scanner-aderyn:0.8.4 → fix is deployed
```

**Root cause:** Both `run-aderyn.sh` and `run-slither.sh` Foundry-project branches detected an existing `foundry.toml` and patched `offline = true` plus optimizer format, but did not add an OpenZeppelin remapping. Real customer Foundry projects that use `@openzeppelin/contracts/` via npm (not `forge install`) ship no remappings in `foundry.toml` because Foundry resolves from `node_modules` locally — a directory not present in the scanner workspace. Without the remapping, `forge build` silently compiled a partial AST (OZ inheritance chain missing), the scanner found 0 issues, and the wrapper POSTed a false-pass.

**Resolution:** Upgrade to scanner-aderyn:0.8.5 and scanner-slither:0.4.7 (initial fix) and the 2026-05-04 sweep at scanner-echidna:0.5.4, scanner-medusa:0.4.4, and scanner-soliditydefend:0.9.10. Each wrapper now appends `@openzeppelin/contracts/=/opt/openzeppelin/v5/` to a local `remappings.txt` in the project workspace when (a) `@openzeppelin/contracts/` imports are detected in `.sol` files AND (b) `foundry.toml` does not already declare a remapping for that prefix. The `remappings.txt` approach is non-destructive (the customer's `foundry.toml` is unchanged), respects user-declared remappings (which take precedence over `remappings.txt`), and is idempotent.

The wake variant of this fix is implemented differently because wake uses its own `wake compile` rather than `forge build` — see Issue 16.

**Verify fix is deployed:**

```bash
# Check aderyn / slither (initial)
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_ADERYN}'
# Expected: .../scanner-aderyn:0.8.5

kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_SLITHER}'
# Expected: .../scanner-slither:0.4.7

# Check sweep targets (2026-05-04)
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_WAKE}'
# Expected: .../scanner-wake:0.5.8 (see Issue 16 for wake-specific notes)

kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_ECHIDNA}'
# Expected: .../scanner-echidna:0.5.4

kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_MEDUSA}'
# Expected: .../scanner-medusa:0.4.4

kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_SOLIDITYDEFEND}'
# Expected: .../scanner-soliditydefend:0.9.10
```

**Scope:** Applies to Foundry projects importing `@openzeppelin/contracts/` v5.0.2 (bundled in the base image at `/opt/openzeppelin/v5/`). Projects that already declare `@openzeppelin/contracts/` in `foundry.toml` remappings (e.g., vendored via `forge install` pointing to `lib/openzeppelin-contracts/`) are unaffected — their remapping takes precedence and the injection is skipped. The same gap was present in the wake, echidna, medusa, and soliditydefend Foundry branches and was closed in the 2026-05-04 sweep (see Issue 16 for the wake-specific regression and target_version follow-up). halmos's scanner architecture is symbolic-execution-only and does not run a compile-then-analyze pipeline; it is not affected.

**TaskDoc:** `TaskDocs-BlockSecOps/scanners/task-179-aderyn-slither-foundry-oz-silent-fail-2026-05-03.md` (original); sweep follow-up captured in `TaskDocs-BlockSecOps/audit-2026-05-04-scanner-full-reaudit.md`.

---

### Issue 16: Wake target_version + NetworkPolicy Egress (Resolved 2026-05-05)

**Status: Resolved at scanner-wake:0.5.8**

**Symptoms (pre-fix):**

Two distinct symptom shapes depending on the wake version:

1. wake 0.5.6 (post-Issue-15 sweep, pre-#192 fix): Foundry+OZ projects scanned to `status: failed` with a parser/compile error in `error_message`. This was a regression — the same project on wake 0.5.5 had silently false-passed with `status: completed, vulnerabilities:[]`.
2. wake 0.5.7 (#192 first attempt, broken): Foundry+OZ projects scanned to `status: failed` with a network resolution error referencing `binaries.soliditylang.org`. The scanner pod attempted an outbound HTTPS call that the namespace's `default-deny-all` NetworkPolicy egress block (correctly) refused.

**Root Cause:**

Wake's compile pipeline differs from forge's. When wake encounters Solidity sources without a wake-native config, it falls back to refreshing its solc-list metadata over the network (via `aiohttp` to `binaries.soliditylang.org`). In the scanner namespace this is blocked by NetworkPolicy egress rules — by design, since scanner pods must not exfiltrate customer source code or pull arbitrary remote artifacts at scan time.

The Issue-15 sweep added `remappings.txt` to wake's Foundry branch under the assumption that wake would benefit from the same `forge build` resolution improvement aderyn/slither got. Wake's compile pipeline is not driven by `forge build`, so the remappings.txt change had no positive effect — it merely surfaced wake's pre-existing parser sensitivity to fully-resolved OZ inheritance chains as a hard failure rather than a silent zero-finding pass.

The 0.5.7 attempted fix wrote a `wake.toml` with the OZ remapping but no `target_version`. Wake interpreted the absent `target_version` as "you haven't told me which solc to use, let me ask binaries.soliditylang.org" — which the NetworkPolicy egress block correctly denied.

**Resolution:**

Wake 0.5.8's `wake-scan` wrapper writes a `wake.toml` with both `target_version` (matching the `SOLC_VERSION` env var, default `0.8.20`) and the OZ remapping when the project imports OZ and no `wake.toml` exists. With `target_version` set, wake's compile pipeline skips the metadata refresh entirely and uses the seeded compilers in `~/.local/share/wake/compilers/`, populated at image build time from `/opt/wake-compilers/`. Compile is fully offline and NetworkPolicy-compliant.

**Verify fix is deployed:**

```bash
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_WAKE}'
# Expected: .../scanner-wake:0.5.8
```

**Scope:** Applies to Foundry+OZ projects scanned by wake. Projects shipping their own `wake.toml` are unaffected — the wrapper's write is gated on `wake.toml` not existing. Scanner-namespace NetworkPolicy egress rules remain intact (no allowlist for soliditylang.org); the fix is "don't make the call," not "let the call out."

**TaskDoc:** `TaskDocs-BlockSecOps/audit-2026-05-05-wake-target-version-regression.md`.

---

### Issue 17: Six cluster-verified scanner failure modes (Resolved 2026-05-06)

**Status:**
- scanner-trident: **0.4.3**
- scanner-cargo-fuzz-solana: **0.4.3**
- scanner-medusa: **0.4.5**
- scanner-mythril: **0.2.10**
- tool-integration: **0.6.28** (KJM `_should_skip_scanner` gate; Task #183 implemented)
- api-service: **0.43.6** (blob-import validation; completed-with-error preservation)

The 2026-05-05 production audit (97 scans across 17 scanners × 11 fixture types) surfaced six cluster-verified failure modes. All six fixed in this round.

#### F1 — trident: opaque "Anchor build failed" message

**Symptoms (pre-fix):** `error_message: "Anchor build failed"` with no diagnostic data on 3 of 4 anchor fixtures.

**Root cause:** `scanner-images/trident/trident-scan` did `anchor build 2>&1` which routed both stdout and stderr to pod stdout. The actual `cargo build` / `anchor` error (toolchain mismatch, missing `provider` in Anchor.toml, `overflow-checks` not enabled, etc.) was lost — only the generic message reached the customer.

**Fix:** Capture build output to a tempfile (`BUILD_LOG=$(mktemp)`), surface the last 250 chars (newline-stripped, length-bounded) in `update_status` error message. `exit 1 → exit 0` so K8s doesn't backoff-retry on a known failure (status is already POSTed).

Pattern mirrors the slither/aderyn forge-build-attribution fix from PR #168.

**Verify:**
```bash
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_TRIDENT}'
# Expected: scanner-trident:0.4.3
```

After fix, customers see actual build errors:
- `Anchor build failed (exit 1): Error: \`overflow-checks\` is not enabled. To enable, add: [profile.release] overflow-checks = true in workspace root Cargo.toml`
- `Anchor build failed (exit 1): Error: Unable to deserialize config: TOML parse error at line 1, column 1 | 1 | [features] | ^ missing field \`provider\``

#### F2 — cargo-fuzz-solana: Cargo.toml only checked at root

**Symptoms (pre-fix):** Workspace anchor projects with `Cargo.toml` in `programs/<crate>/` rejected with `Not a Rust project - cargo-fuzz requires Cargo.toml`.

**Root cause:** `scanner-images/cargo-fuzz-solana/cargo-fuzz-solana-scan:146` checked `[ ! -f "$WORK_DIR/Cargo.toml" ]` — root only. Anchor workspace projects ship Cargo.toml inside `programs/<crate>/`.

**Fix:** Tree-walk up to depth 3 with `find -maxdepth 3 -name Cargo.toml -type f`. Accept the project if any nested Cargo.toml is found. Do **not** rebind `$WORK_DIR` — vendor seeding + Rust-file discovery use absolute path, and cargo's own resolver finds nested crates from the root once any Cargo.toml exists.

#### F3 — medusa: bash heredoc emits invalid JSON when fuzz vars are empty

**Symptoms (pre-fix):** `error_message: "Medusa produced no valid output — check scanner logs"` on Foundry projects without property-test invariants.

**Root cause:** `scanner-images/medusa/medusa-scan:402-427` used a bash heredoc with raw shell-variable interpolation to construct the result JSON. When fuzz vars (`TESTS_RUN`, `COVERAGE_PERCENT`, etc.) were empty, the heredoc emitted invalid JSON like `"tests_executed": ,` — the EXIT-trap `jq empty` validator rejected it and the post_callback fallback fired with the opaque error message. **Pre-existing bug since 2025-10-15** (medusa's first import); echidna got the equivalent jq-based rewrite in 2026-04-14, medusa was missed.

**Fix:** Replace the heredoc with `jq -n --arg/--argjson` (matches echidna pattern). Schema is identical field-by-field. `${VAR:-0}` defaults guard against unset vars. If jq fails, OUTPUT_FILE is removed so EXIT-trap fallback fires with a clear error.

#### F4 — mythril: opaque `exit_1` per-file failure code

**Symptoms (pre-fix):** `error_message: "/contracts/contract.sol:exit_1"` on single-file Solidity 0.8.20 scans. Operators couldn't tell whether the cause was timeout, OOMKill, or analysis crash without pulling pod logs.

**Root cause:** `scanner-images/mythril/run-mythril.sh` per-file failure tracking (Task #182) used `FILE_FAIL_REASON="exit_${MYTH_EXIT}"` for any non-timeout failure. This was opaque diagnostic data.

**Fix:** Refine the case statement to surface known exit codes:
- `124` → `timeout` (existing — preserved)
- `137` → `oomkill_${MYTHRIL_MEMORY_LIMIT_MB:-2048}MB`
- `1` → `exit_1_check_pod_logs`
- other → `exit_${MYTH_EXIT}` (fallback preserved)

#### F5 — mythril multi-file Hardhat: structurally OOMs at 2Gi (Task #183)

**Symptoms (pre-fix):** mythril on multi-file Hardhat projects ran for ~5-15 minutes then OOMKilled with `error_message: "exit_1 on <file>.sol"`. Customer paid for compute that was structurally guaranteed to fail.

**Root cause:** mythril's z3 SMT solver memory grows exponentially with code branches. Multi-file Hardhat fixtures consistently exceed the 2Gi container limit. Verified Task #182 on 2026-05-03; Task #183 filed for the auto-skip implementation.

**Fix (Task #183):** New `_should_skip_scanner()` helper in `tool-integration/src/scanners/kubernetes_job_manager.py` plus a dispatch hook in `src/main.py`. The gate fires when `scanner == "mythril" AND framework == "hardhat" AND file_count > 1`, returns `(True, reason)` to the dispatcher, and the dispatcher fires a synthetic terminal callback with `status: "completed"`, `error: "<gate reason>"`, `vulnerabilities: []`. Detection is canonical config-file based (any `hardhat.config.{js,ts,cjs,mjs}` triggers Hardhat detection) — no api-service coordination required.

**Why `status: "completed"` instead of `"failed"`:** the api-service first-terminal-wins guard at `scans.py:2317` (BSO-BUG-170 symmetric, Task #182) blocks subsequent successful scanner callbacks once any scanner reports failed first. Sending failed for the gate would break multi-scanner scans that include mythril alongside slither/wake/etc — the other scanners would complete fine but the scan would stay stuck at "failed" with 0 findings. Sending completed-with-populated-error preserves both:
- The customer sees a successful scan with the other scanners' findings aggregated
- The error_message communicates that mythril was skipped and why
- Customers can still re-trigger the scan without mythril, or use one of the alternatives suggested

This required a complementary api-service change (see below) to preserve the error from completed-with-warning callbacks.

**Synthetic callback payload (tool-integration → api-service):**
```json
{
  "scanner": "mythril",
  "status": "completed",
  "error": "mythril does not support multi-file Hardhat projects (z3 SMT solver memory ceiling at 2Gi). Use slither, aderyn, wake, halmos, echidna, or medusa for multi-file coverage.",
  "vulnerabilities": []
}
```

The synthetic callback is fire-and-forget (`asyncio.create_task`) — the dispatch trigger returns HTTP 200 immediately so the api-service `/api/v1/scans` request doesn't time out at the Cloudflare 100s edge timeout while waiting for tool-integration.

#### F6 — api-service blob URLs with relative imports

**Symptoms (pre-fix):** `POST /api/v1/contracts/from-github` with a blob URL of a `.sol` file containing `import "./IERC20.sol";` succeeded; downstream scanners (especially mythril) then choked with confusing `ParserError: Source IERC20.sol not found` because `fetch_blob()` retrieves only the single file.

**Root cause:** Per `docs/workflows/contract-ingest-workflow.md` §3, the platform's design separates ingest paths: blob = single self-contained file, tree = directory. A blob URL with relative imports violates this boundary. The fetcher had no validation, so the violation cascaded into a confusing scanner error.

**Fix:** Validate at upload time. After `fetch_blob()` returns source code, scan `.sol`/`.vy` files for line-anchored relative-import patterns:
```python
re.search(r'^\s*import\s+["\']\.\.?/[^"\']+["\']', source_code, flags=re.MULTILINE)
```

If matched, return HTTP 400 with error key `blob_has_relative_imports` and a message pointing to the canonical alternative paths (tree URL of parent directory; archive upload via `POST /api/v1/upload`). Absolute imports (`@openzeppelin/contracts/...`, `@uniswap/...`) are unaffected — pattern only matches `./` or `../` prefixes.

#### Companion api-service change: error_message preservation

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py` `store_scan_results()`.

**What changed:** the existing code at line 2335 only set `scan.error_message = results.error` when `results.status == "failed"`. The completed path didn't propagate `error` to the scan record. With the F5 KJM gate now sending `status: "completed"` with `error: <gate-reason>`, that path needed to preserve the error for customer visibility:

```python
if results.error and not scan.error_message:
    scan.error_message = results.error
```

`not scan.error_message` keeps the first-non-empty-error-wins behavior (multiple gated scanners or gate + later scanner-with-warning don't clobber each other; first gate's reason wins).

#### Verify all six fixes deployed

```bash
# Tool-integration
kubectl get deployment tool-integration -n tool-integration-prod \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: ...tool-integration:0.6.28

# api-service
kubectl get deployment api-service -n api-service-prod \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: ...api-service:0.43.6

# Scanner image versions
for s in TRIDENT CARGO_FUZZ_SOLANA MEDUSA MYTHRIL; do
  echo -n "$s: "
  kubectl get configmap scanner-versions -n tool-integration-prod \
    -o jsonpath="{.data.SCANNER_IMAGE_$s}"
  echo
done
# Expected:
#   TRIDENT: scanner-trident:0.4.3
#   CARGO_FUZZ_SOLANA: scanner-cargo-fuzz-solana:0.4.3
#   MEDUSA: scanner-medusa:0.4.5
#   MYTHRIL: scanner-mythril:0.2.10
```

#### Cluster-verified production smoke test (2026-05-06)

| Fix | Test fixture | Pre-fix | Post-fix |
|---|---|---|---|
| F1 | trident @ E2E-Rust-anchor-basic1-tree, rs_archive.tar, test-anchor-project.tar | `failed`, error_message: "Anchor build failed" | `failed`, error_message: actual `cargo build` / Anchor.toml error tail |
| F2 | cargo-fuzz @ FIX3-Anchor-Escrow workspace | (control) | `completed` cleanly via workspace tree-walk |
| F3 | medusa @ test-foundry-project (Foundry no-OZ) | `failed`, "Medusa produced no valid output" | `completed`, valid JSON output |
| F4 | mythril @ TestA-VulnGood-0.8.20 (single-file) | `failed`, "exit_1" | `failed`, `exit_1_check_pod_logs` |
| F5a | mythril @ hardhat-project-v2 (single-scanner) | `failed` after 5+ min OOMKill | `completed` 0 findings + actionable error_message |
| F5b | mythril+slither+wake @ hardhat-project-v2 | scan stuck `failed` (slither/wake aggregation lost) | `completed` 17 findings (slither+wake) + gate error_message preserved |
| F6 | `POST /contracts/from-github` blob with `import "./X.sol"` | downstream ParserError | HTTP 400 `blob_has_relative_imports` with tree-URL/archive guidance |

**TaskDoc:** `TaskDocs-BlockSecOps/audit-2026-05-06-scanner-failure-fixes.md`.

---

## Scanner Image Version Reference

| Scanner | Image | Version | Base | UID |
|---------|-------|---------|------|-----|
| slither | scanner-slither | 0.4.7 | scanner-base-solidity:1.1.1-37dbe11e | 1000 |
| aderyn | scanner-aderyn | 0.8.5 | scanner-base-solidity:1.1.1-37dbe11e | 1000 |
| semgrep | scanner-semgrep | 0.3.12 | python:3.11-slim | 1000 |
| solhint | scanner-solhint | 0.1.14 | node:20-alpine | 1000 (node) |
| wake | scanner-wake | 0.5.8 | scanner-base-solidity:1.1.1-37dbe11e | 1000 |
| soliditydefend | scanner-soliditydefend | 0.9.9 | debian:bookworm-slim (Rust builder) | 1000 |
| echidna | scanner-echidna | 0.5.4 | scanner-base-solidity:1.1.1-37dbe11e | 1000 |
| halmos | scanner-halmos | 0.4.3 | scanner-base-solidity:1.1.0-b49e3f10 | 1000 |
| medusa | scanner-medusa | 0.4.5 | scanner-base-solidity:1.1.1-37dbe11e | 1000 |
| mythril | scanner-mythril | 0.2.10 | scanner-base-solidity:1.1.1-37dbe11e | 1000 |
| vyper | scanner-vyper | 0.3.5 | python:3.11-slim | 1000 |
| moccasin | scanner-moccasin | 0.3.3 | python:3.11-slim | 1000 |
| sol-azy | scanner-sol-azy | 0.5.1 | rust:1.88-bookworm | 1000 |
| sec3-xray | scanner-sec3-xray | 0.4.1 | ghcr.io/sec3-product/x-ray:v0.0.6 | 1000 |
| trident | scanner-trident | 0.4.3 | rust:1.88-bookworm | 1000 |
| cargo-fuzz-solana | scanner-cargo-fuzz-solana | 0.4.3 | rust:1.85-bookworm + nightly | 1000 |
| rustdefend | scanner-rustdefend | 0.4.6 | debian:bookworm-slim | 1000 |

---

## Verification Commands

```bash
# Check all scanner image versions in ConfigMap
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | grep SCANNER_IMAGE

# Check tool-integration default images
kubectl exec -n tool-integration-local deployment/tool-integration -- python3 -c "
from src.scanners.kubernetes_job_manager import KubernetesJobManager
print(KubernetesJobManager.default_images)
"

# Trigger a test scan
SCAN_ID=$(python3 -c 'import uuid; print(uuid.uuid4())')
kubectl exec -n tool-integration-local deployment/tool-integration -- python3 -c "
import requests
resp = requests.post('http://localhost:8005/scans/$SCAN_ID/trigger?scanner=solhint', json={
    'contract_source': 'pragma solidity ^0.8.0; contract Test { function f() public {} }',
    'contract_name': 'Test.sol'
})
print(resp.json())
"

# Watch for results
kubectl logs -n tool-integration-local deployment/tool-integration -f | grep "$SCAN_ID"
```

---

### Issue 8: 409 Conflict on Job Creation (Stale Jobs)

**Symptoms:**
- `Request failed with status code 409` when uploading a contract
- Scanner Job creation fails with `ApiException(409)`
- Retries of the same scan always fail

**Root Cause:** Job names previously used `scan_id[:8]` (only 4 bytes of entropy from the UUID). This caused collisions between different scans and 409 Conflict errors when retrying the same scan (stale Job with the same truncated name still exists).

**Fix (applied in kubernetes_job_manager.py):**
1. Job names now use the full scan_id: `scan-{scanner}-{scan_id}` (max 59 chars, under K8s 63-char limit)
2. ConfigMap names use the full scan_id: `scan-{scan_id}-source` (max 48 chars)
3. Job creation handles 409 with a proper poll-based wait loop:

```python
except ApiException as e:
    if e.status == 409:
        self.delete_job(job_name, propagation_policy="Background")
        for attempt in range(10):
            time.sleep(2)
            try:
                self.batch_v1.read_namespaced_job(name=job_name, namespace=self.namespace)
            except ApiException as check_err:
                if check_err.status == 404:
                    break  # Job is gone
                raise
        # Recreate the Job
        self.batch_v1.create_namespaced_job(namespace=self.namespace, body=job)
```

**Verification:**
```bash
# Check job naming uses full scan_id (no truncation)
grep 'job_name.*scan_id' src/scanners/kubernetes_job_manager.py

# Run regression tests
pytest tests/regression/test_job_name_collision.py -v
```

---

### Issue 12: Scan flipped from `completed` to `failed` after the scanner finished successfully (Job-cleanup race)

**Symptoms (pre-0.43.1):**
- Scanner pod succeeded per `kubectl get events` and tool-integration logs
- api-service received a `POST /results` with `status=completed` and persisted findings
- Later, the scan record shows `status=failed, error_message="Job failed after all retries"`
- api-service logs show 2–3 POSTs to `/results` from tool-integration pod IPs, some later ones with `status=failed`

**Root cause:** wake's scanner wrapper does `curl --retry 3 --retry-all-errors` on the callback. When the K8s Job cleanup detects the pod as Failed (backoff_limit or activeDeadlineSeconds), `result_collector.py:315` POSTs a `status=failed, error="Job failed after all retries"` callback. Pre-0.43.1, api-service unconditionally overwrote `scan.status`, clobbering the earlier `completed` state.

**Fix (api-service 0.43.1 — original arm; 0.43.4 — symmetric guard):** `store_scan_results` has a terminal-state guard at the top. The original arm (0.43.1) rejects `failed`-after-`completed` callbacks. The symmetric arm (0.43.4, Task #182) also rejects `completed`-after-`failed` callbacks, eliminating the inverse race where the result_collector's failure POST lands first and the wrapper's success POST arrives second and silently flips the state. First terminal callback wins in both directions.

**How to detect the guard firing in logs:**
```bash
kubectl logs -n api-service-prod -l app.kubernetes.io/name=api-service --tail=1000 \
  | grep "Ignoring failed callback for already-completed scan"
```

Each log line is one prevented overwrite — these are informational, not errors.

**What the guard blocks (as of api-service:0.43.4, symmetric guard):**
- `completed → failed` — rejected; first terminal callback wins (original BSO-BUG-170 arm)
- `failed → completed` — rejected; first terminal callback wins (symmetric arm added 2026-05-03, Task #182)

**What is allowed:**
- `queued → completed` / `queued → failed` — first terminal callback accepted
- `completed → completed` — multi-scanner accumulation via `scan.critical_count += ...` is intact
- `failed → failed` — idempotent no-op

**Live verification if you suspect a regression:**
```bash
INTERNAL_KEY=$(kubectl get secret api-service-secret -n api-service-prod -o jsonpath='{.data.INTERNAL_SERVICE_KEY}' | base64 -d)
SCAN_ID=<pick-a-completed-scan>
curl -sS -X POST https://app.0xapogee.com/api/v1/scans/$SCAN_ID/results \
  -H "X-Internal-Service-Key: $INTERNAL_KEY" -H "Content-Type: application/json" \
  -d '{"scanner":"wake","status":"failed","error":"test","vulnerabilities":[]}'
# expect: {"ignored": true, "prior_status": "completed", ...}
# then re-GET and confirm scan record unchanged
```

---

### Issue 13: Mythril urllib3 NameResolutionError on solc-bin.ethereum.org

**Status: Resolved at scanner-mythril:0.2.7**

**Symptoms (pre-scanner-mythril:0.2.7):**
- Mythril Job exits non-zero
- Wrapper callback POSTs `success=false` with stderr containing a urllib3 traceback:
  ```
  urllib3.exceptions.NameResolutionError: ... Failed to resolve 'solc-bin.ethereum.org'
  ```
- Scan transitions to `failed` with error indicating compile failure
- Only affects Hardhat projects importing `@openzeppelin/contracts/...`

**Root cause:** Mythril uses solc Standard JSON mode (`--standard-json`) via py-solc-x. Standard JSON mode rejects positional `prefix=path` remappings on the command line ("Import remappings are not accepted on the command line in Standard JSON mode") and does not read `foundry.toml`. Without a working OZ remapping, solc cannot resolve `@openzeppelin/contracts/...`, causing py-solc-x to fall back to `solcx.install_solc()` — which attempts to fetch the solc binary from `solc-bin.ethereum.org`, blocked by NetworkPolicy.

**This is NOT a NetworkPolicy misconfiguration** — the block is correct. The underlying issue is the missing OZ remapping for mythril's Standard JSON compile path.

**Diagnosis:**

```bash
# Check pod logs for the urllib3 traceback
kubectl logs -n tool-integration-prod \
  -l job-name=scan-mythril-<scan-id-prefix> --tail=100 | grep -A10 "NameResolutionError\|solc-bin"

# If you see the urllib3 traceback, check the scanner image version
kubectl get pod -n tool-integration-prod \
  -l job-name=scan-mythril-<scan-id-prefix> \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# If version is < 0.2.7, the fix has not been deployed
```

**Fix:** Upgrade to scanner-mythril:0.2.7 or later. The wrapper conditionally writes a Standard JSON settings file (`/tmp/solc-settings.json`) with the OZ remapping in `settings.remappings` and passes it via `--solc-json` — the correct flag for Standard JSON mode.

**Verify fix is deployed:**

```bash
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_MYTHRIL}'
# Expected: .../scanner-mythril:0.2.9
```

**Scope:** Fixed for single-file Hardhat+OZ contracts as of 0.2.7. Multi-file Hardhat projects OOMKill mythril's z3 solver at the 2Gi container memory limit — see Issue 14.

---

### Issue 14: Mythril OOMKilled on Multi-File Hardhat/Foundry Projects

**Status: Known limitation — single-file use only. Auto-skip on multi-file tracked as Task #183 (post-launch).**

**Symptoms:**
- Mythril Job fails for multi-file Hardhat or Foundry projects (2+ contract files)
- Scan record shows `status=failed` with `error_message=null`
- `kubectl get events` shows OOMKilling:
  ```
  OOMKilling  Killed process myth ... total-vm:3012952kB, anon-rss:2088632kB
  ```
- Single-file contracts against the same project framework succeed

**Root cause:** Mythril's z3 SMT solver memory grows exponentially with symbolic branches, not linearly with code size. Multi-file analysis runs z3 sequentially per file; the combined resident set exceeds the 2Gi `tool-integration-prod` LimitRange `max.memory` hard cap even on small contracts (~118 LOC). Real customer DeFi contracts would OOM worse.

**This is NOT a misconfiguration.** The 2Gi cap is deliberate. Bumping it further would require a deliberate namespace-wide LimitRange change and would still not guarantee mythril completes on realistic contracts.

**Why `error_message` is null:** The pod is hard-killed by the kernel (SIGKILL via memory cgroup) mid-execution. The wrapper's `exit 0` path — which writes the summary `error` field the api-service schema reads — is never reached. The EXIT trap's fallback fires, but it emits the `errors` array only, which the `ScanResults` Pydantic schema silently drops (it declares `error: Optional[str]`, not an array). This is cosmetic — the scan correctly reaches `failed` status.

**Diagnosis:**

```bash
# Check OOMKill events for a mythril Job pod
kubectl get events -n tool-integration-prod \
  --field-selector involvedObject.kind=Pod \
  | grep -E "scan-mythril-<scan-id-prefix>|OOMKill"

# Confirm scan status and missing error_message via API
curl -sk https://app.0xapogee.com/api/v1/scans/<scan_id> \
  -H "Authorization: Bearer $TOKEN" | jq '{status, error_message}'
# Expected: {"status": "failed", "error_message": null}

# Confirm the scanner image version is current
kubectl get configmap scanner-versions -n tool-integration-prod \
  -o jsonpath='{.data.SCANNER_IMAGE_MYTHRIL}'
# Expected: .../scanner-mythril:0.2.9
```

**Resolution for operators:** Instruct the user to scan against a single-file entry-point contract, or to use any of the other six Solidity scanners (slither, aderyn, wake, halmos, echidna, medusa), all of which handle multi-file projects correctly and cover mythril's detector classes.

**Post-launch fix (Task #183):** The KJM will gate on `contract.is_multi_file == True` or `contract.file_count > 1` and mark mythril as `skipped` (not `failed`) with reason "skipped: mythril requires single-file contracts at current memory budget". The dashboard will display `skipped` distinctly from `failed`.

---

### Issue 9: Failed Callback Results Lost (No Dead-Letter)

**Symptoms:**
- Scanner completes and sends results, but API service is temporarily down
- Results forwarded by tool-integration get HTTP 5xx from api-service
- Results are lost with only an error log entry

**Fix (applied in main.py and dead_letter.py):**
- Added `DeadLetterStore` that persists failed forwarding payloads to `/tmp/dead-letters/`
- Failed forwards are automatically dead-lettered with scan_id, scanner, payload, and error
- Management endpoints:
  - `GET /api/v1/dead-letters` - List pending entries
  - `POST /api/v1/dead-letters/{id}/retry` - Retry forwarding
  - `DELETE /api/v1/dead-letters/{id}` - Discard entry
- Dead-letter count appears in `/health` response

**Verification:**
```bash
# Check dead-letter queue
curl -s http://127.0.0.1:8005/api/v1/dead-letters | jq .count
```

---

## Operational Improvements (February 2026)

### Readiness Endpoint

The `/ready` endpoint was missing from `main.py` despite being configured in the K8s readiness probe. Now implemented with checks for:
- `job_manager` initialization
- `collector_task` liveness (background polling running)

Returns HTTP 503 with reasons when not ready.

### Structured JSON Logging

Logging switched from plain-text to structured JSON format with correlation IDs:
```json
{"ts": "2026-02-12 19:44:12", "level": "INFO", "logger": "src.main", "msg": "...", "request_id": "abc-123", "scan_id": "def-456"}
```

`X-Request-ID` header is propagated through requests and returned in responses. `scan_id` is extracted from URL paths automatically.

### Prometheus Alerting Rules

New `PrometheusRule` (`k8s/base/prometheus-rules.yaml`) with alerts:
- `ScannerHighFailureRate` - >25% failure rate over 15 minutes
- `ScannerPipelineStalled` - Triggers sent but no callbacks received
- `JobConflictRateHigh` - High 409 Conflict rate
- `CallbackForwardingFailure` - API forwarding failing >10%
- `ScannerJobStuck` - Jobs running >15 minutes

### Port Fixes

Fixed mismatched ports in base K8s manifests:
- `deployment.yaml`: Prometheus annotation `8001` corrected to `9090`
- `ingress.yaml`: Backend service port `8001` corrected to `8005`
- `network-policy.yaml`: Ingress rules `8000` corrected to `8005`

---

## Related Documentation

- [Scanner Upgrade Playbook](./upgrade-scanner-image.md)
- [Scanner Data Audit](./scanner-data-audit.md)
- [Smart Contract Scanning Workflow](../workflows/smart-contract-scanning-workflow.md)
- [Feature Test: Scanner Pipeline E2E](../feature-tests/62-scanner-pipeline-e2e.md)
