# Tool Integration v0.4.1 - SolidityDefend Parser Fix

**Date:** February 12, 2026
**Component:** blocksecops-tool-integration
**Version:** 0.4.0 → 0.4.1
**PR:** #94

---

## Summary

Fixed SolidityDefend scanner returning 0 vulnerabilities due to a JSON key mismatch between the scanner entrypoint output and the parser in `main.py`.

---

## Root Cause

The SolidityDefend scanner entrypoint (`soliditydefend-scan`) uses jq to transform native SolidityDefend JSON output into a standardized format. The transformation outputs results under the `"vulnerabilities"` key. However, the parser in `main.py` (line 1325) only checked `results_json.get("findings", [])`.

Additionally, the entrypoint transforms field names:
- `detector_id` → `id`
- `message` → `description`
- `location` → `locations` (array)

But the parser expected the native format fields.

---

## Fix

The parser now handles both formats:

1. **Key lookup** — Checks both `"findings"` and `"vulnerabilities"` keys:
   ```python
   findings_raw = results_json.get("findings", []) or results_json.get("vulnerabilities", [])
   ```

2. **Field format detection** — Handles both native and transformed formats:
   - Native: `detector_id`, `message`, `location` (object)
   - Transformed: `id`, `title`, `description`, `locations` (array)

---

## Files Modified

| File | Change |
|------|--------|
| `src/main.py` (lines 1320-1377) | SolidityDefend parser: check both keys, handle both field formats |
| `pyproject.toml` | 0.4.0 → 0.4.1 |
| `k8s/overlays/local/kustomization.yaml` | newTag + version label → 0.4.1 |

---

## Verification

After deploying v0.4.1, trigger a scan with SolidityDefend on any Solidity contract. The scan results should now contain parsed vulnerabilities with correct severity, title, description, and line numbers.

```bash
# Verify via database
kubectl exec -n postgresql-local deploy/postgresql -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT scanner_name, COUNT(*) FROM vulnerabilities WHERE scanner_name = 'soliditydefend' GROUP BY scanner_name;"
```
