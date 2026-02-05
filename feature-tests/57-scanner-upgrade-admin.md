# Scanner Upgrade via Admin Dashboard

**Priority**: P1 - Important
**Last Tested**: February 5, 2026
**Endpoint**: `POST /api/v1/admin/system/scanners/{name}/upgrade`

---

## 1. Version Detection

### 1.1 Latest Version Display
- [ ] Admin System → Security Scanners shows current version for each scanner
- [ ] Latest version fetched from GitHub API (1-hour cache)
- [ ] Yellow `→ x.y.z` indicator shown when versions differ
- [ ] Scanners without GitHub mapping show no latest version
- [ ] Cache refreshes after 1 hour

### 1.2 Scanner Health Table
- [ ] All registered scanners appear in table
- [ ] Health status (Healthy/Degraded) displayed correctly
- [ ] Job counts (Total/Failed/Running) accurate
- [ ] "Actions" column visible with Upgrade button

---

## 2. Upgrade Button

### 2.1 Button Visibility
- [ ] "Upgrade" button shown only when `latest_version !== version`
- [ ] Button hidden when scanner is up-to-date
- [ ] Button hidden when latest version is unknown/null
- [ ] Button styled with `ArrowUpCircleIcon`

### 2.2 Confirmation Dialog
- [ ] Clicking "Upgrade" opens confirmation modal
- [ ] Modal shows scanner name
- [ ] Modal shows version transition (e.g., `0.10.3 → 0.10.4`)
- [ ] Info notice about Docker image rebuild displayed
- [ ] Optional reason field available
- [ ] "Cancel" button closes dialog
- [ ] "Confirm Upgrade" button initiates upgrade

---

## 3. Upgrade Execution

### 3.1 API Proxy (API Service)
- [ ] `POST /admin/system/scanners/{name}/upgrade` requires `platform_admin` role
- [ ] Invalid scanner names rejected (400)
- [ ] Request proxied to tool-integration service
- [ ] Timeout set to 60 seconds
- [ ] Admin action logged in audit trail

### 3.2 ConfigMap Update (Tool Integration)
- [ ] ConfigMap `scanner-versions` read from K8s API
- [ ] `SCANNER_METADATA` JSON updated with new version
- [ ] `_note` field updated with date and source
- [ ] ConfigMap patched in Kubernetes
- [ ] In-memory metadata updated
- [ ] Deployment rollout restart triggered

### 3.3 Success Response
- [ ] Response includes `success: true`
- [ ] Previous and new version numbers returned
- [ ] List of completed steps returned
- [ ] Message includes note about Docker image rebuild
- [ ] Steps list displayed in UI

### 3.4 Error Handling
- [ ] Non-existent scanner returns 404
- [ ] K8s API errors caught and returned as `success: false`
- [ ] Error message displayed in UI
- [ ] Partial step list shows what completed before failure

---

## 4. Post-Upgrade Verification

### 4.1 ConfigMap Updated
```bash
kubectl get cm scanner-versions -n tool-integration-local \
  -o jsonpath='{.data.SCANNER_METADATA}' | jq '.<scanner>.version'
# Should show new version
```

### 4.2 Scanner Health Refresh
- [ ] After upgrade, refreshing scanner health shows updated version
- [ ] Upgrade indicator disappears if versions now match
- [ ] Pod restart completes without errors

### 4.3 Audit Trail
- [ ] Admin System → Audit Log shows `admin.scanner.upgrade` action
- [ ] Audit entry includes target scanner name
- [ ] Audit entry includes target version and success status

---

## 5. Authorization & Security

### 5.1 Access Control
- [ ] Non-admin users cannot access upgrade endpoint (403)
- [ ] Non-platform_admin roles cannot upgrade (403)
- [ ] Valid admin token required (401 without)

### 5.2 Input Validation
- [ ] Scanner name validated (alphanumeric + hyphens/underscores)
- [ ] Target version required (min 1, max 50 chars)
- [ ] Reason field optional (max 500 chars)

---

## 6. RBAC Verification

### 6.1 ServiceAccount Permissions
```bash
# Verify tool-integration SA can patch configmaps
kubectl auth can-i patch configmaps \
  --as=system:serviceaccount:tool-integration-local:tool-integration-sa \
  -n tool-integration-local
# Should return: yes

# Verify tool-integration SA can patch deployments
kubectl auth can-i patch deployments \
  --as=system:serviceaccount:tool-integration-local:tool-integration-sa \
  -n tool-integration-local
# Should return: yes
```

---

## 7. Upgrade Pipeline Results (v0.25.9+)

### 7.1 Pipeline Execution
- [ ] After successful ConfigMap update, pipeline runs automatically
- [ ] Detector comparison phase executes
- [ ] Pattern seeding phase executes
- [ ] Audit validation phase executes
- [ ] Pipeline results included in API response under `pipeline` field

### 7.2 Detector Comparison Display
- [ ] "Pipeline Results" section appears in upgrade dialog after success
- [ ] New detector count displayed
- [ ] Changed detector count displayed
- [ ] Removed detector count displayed
- [ ] Section hidden if detector comparison data is null (no detector list available)
- [ ] Error message shown if detector comparison failed

### 7.3 Pattern Seeding Display
- [ ] Patterns created count displayed
- [ ] Mappings created count displayed
- [ ] Section hidden if no unmapped detectors found
- [ ] Error message shown if pattern seeding failed

### 7.4 Health Score Display
- [ ] Health score percentage displayed
- [ ] Health status text displayed (healthy/needs_attention/critical)
- [ ] Green color for score >= 90%
- [ ] Yellow color for score >= 70% and < 90%
- [ ] Red color for score < 70%
- [ ] Error message shown if audit failed

### 7.5 Pipeline Error Handling
- [ ] Individual phase failure does not block other phases
- [ ] Phase errors shown inline (e.g., `detector_comparison.error`)
- [ ] Overall upgrade still marked as success if ConfigMap update succeeded
- [ ] Steps list includes pipeline phase descriptions
- [ ] Audit log entry includes pipeline success/failure status

### 7.6 Pipeline Results in Audit Log
- [ ] Admin System → Audit Log → `admin.scanner.upgrade` entry includes pipeline data
- [ ] Pipeline steps visible in audit entry details
- [ ] Health score recorded in audit trail

---

## Related Tests

- [06-scanning.md](./06-scanning.md) - Scan trigger and results tests
- [22-scanner-validation.md](./22-scanner-validation.md) - Per-scanner validation
- [46-platform-admin-panel.md](./46-platform-admin-panel.md) - Admin panel tests
- [47-api-keys-security.md](./47-api-keys-security.md) - API authentication tests
