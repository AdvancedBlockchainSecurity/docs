# Scanner Base Solidity: Operations Playbook

**Last Updated:** April 19, 2026
**Applies to:** `blocksecops/scanner-base-solidity` base image + its 7 consumers (wake / slither / aderyn / halmos / mythril / echidna / medusa)
**Current base tag in production:** `1.0.0-30aad7ef`

---

## What this image is

One Debian-slim image that carries every solc version, Foundry toolchain, Hardhat, forge-std, and a shared `check-pragma` gate. Every Solidity scanner's Dockerfile does `FROM scanner-base-solidity:{tag}` and only adds its own tool. A new solc version is a one-file change in the base instead of seven per-scanner changes.

**What's inside:**
- Python 3.11 slim (digest-pinned)
- Node 20 LTS + Hardhat 2.22.17 + hardhat-toolbox 5.0.0
- Foundry (forge, cast, anvil) from the official digest-pinned image
- forge-std v1.9.6 (SHA-256 verified tarball)
- solc-select 1.1.0 + py-solc-x 2.0.3 + crytic-compile 0.3.7
- 17 solc versions (0.8.12 → 0.8.28, continuous, all post-2022-01-17), each SHA-256 verified against `binaries.soliditylang.org/linux-amd64/list.json`, laid out in three paths:
  - `/opt/solc-select/artifacts/solc-{ver}/solc-{ver}` (solc-select)
  - `/opt/svm/{ver}/solc-{ver}` (Foundry SVM)
  - `/opt/wake-compilers/{fullname}/{fullname}` + `solc.json` (wake)
  - mythril synthesizes its own `/opt/solcx/` layer via symlinks — see `scanner-images/mythril/Dockerfile`
- `/usr/local/bin/check-pragma` — Python stdlib script that rejects contracts targeting solc < 0.8.12
- Non-root `scanner` user (UID 1000, `/sbin/nologin`, home 0700)

---

## When to change it

| Change | Bump | Effort |
|---|---|---|
| Add a newer solc version (e.g., `0.8.29` drops) | PATCH on base; no scanner bumps required | ~15 min |
| Update Foundry / Hardhat / forge-std | MINOR on base; rebuild all 7 scanners (they pick up the new tools automatically via base) | ~30 min per scanner |
| Change the minimum-supported cutoff | MINOR on base (`check-pragma` logic change); update `feature-tests/11-pragma-gate.md`; optional: update the `check-pragma` script's error message | ~20 min |
| Security patch to a bundled binary | PATCH on base; cascade rebuild of all 7 scanners | ~1 h |

**Every change requires:** edit in `blocksecops-tool-integration/scanner-images/_base/Dockerfile`, rebuild with a new tag, push to Artifact Registry, update scanner Dockerfiles' `ARG BASE_IMAGE_TAG=` defaults, rebuild + push all 7 scanners, update ConfigMap (`SCANNER_IMAGE_*`) + KJM `default_images`, rebuild + push tool-integration, apply + rollout. Per `docs/standards/core-development-rules.md` Rule 0, every step is a separate owner approval.

---

## Procedure: add a new solc version

1. Check the upstream release manifest to confirm the version exists and has a published SHA-256:
   ```bash
   curl -sSL https://binaries.soliditylang.org/linux-amd64/list.json | \
     jq '.releases["0.8.29"]'
   ```
2. Add the version to the install loop in `scanner-images/_base/Dockerfile` (find the `for VERSION in ...` block). Add it to `_base/solc-versions.txt` too — that file is the human-readable source-of-truth for review diffs.
3. Compute the new Dockerfile hash:
   ```bash
   sha256sum scanner-images/_base/Dockerfile | cut -c1-8
   ```
4. Rebuild the base image locally (verifies the in-Dockerfile `check-pragma` self-test passes):
   ```bash
   REGISTRY=us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee
   NEW_HASH=$(sha256sum scanner-images/_base/Dockerfile | cut -c1-8)
   BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ"); VCS_REF=$(git rev-parse --short HEAD)
   DOCKER_BUILDKIT=1 docker build --provenance=false \
     --build-arg BASE_IMAGE_VERSION=1.0.0 \
     --build-arg BASE_IMAGE_HASH=${NEW_HASH} \
     --build-arg BUILD_DATE="${BUILD_DATE}" \
     --build-arg VCS_REF="${VCS_REF}" \
     -t ${REGISTRY}/blocksecops/scanner-base-solidity:1.0.0-${NEW_HASH} \
     scanner-images/_base/
   ```
5. Verify: `docker run --rm ${REGISTRY}/blocksecops/scanner-base-solidity:1.0.0-${NEW_HASH} solc-select versions | wc -l` should match the new total count.
6. **Owner approval required** before `docker push`.
7. Push: `docker push ${REGISTRY}/blocksecops/scanner-base-solidity:1.0.0-${NEW_HASH}`
8. Update each scanner Dockerfile's `ARG BASE_IMAGE_TAG=1.0.0-...` default to the new hash.
9. Rebuild + push all 7 scanners sequentially (PATCH bump each, e.g., wake 0.5.0 → 0.5.1):
   ```bash
   for scanner in wake slither aderyn halmos mythril echidna medusa; do
     # Bump ARG SCANNER_IMAGE_VERSION in scanner's Dockerfile
     # Build + push with provenance=false
   done
   ```
10. Update ConfigMap `scanner-versions-configmap.yaml` with new scanner tags.
11. Update KJM `default_images` in `src/scanners/kubernetes_job_manager.py`.
12. Bump tool-integration PATCH (KJM changed); rebuild + push.
13. `kubectl apply -k k8s/overlays/gcp/` + `kubectl rollout restart deployment/tool-integration -n tool-integration-prod`.
14. Smoke test: submit a scan on a contract using the new solc version; verify `scan.status=completed`.

---

## Procedure: change the minimum-supported cutoff

**Pre-requisites:** align with product on the new cutoff + a customer-migration plan.

**As of 2026-05-09 (Migration 090, api-service 0.43.11)** the cutoff lives in TWO source-of-truth files. Both must be updated together or the upstream-gate and the wrapper-side backstop will disagree.

1. Edit `blocksecops-api-service/src/domain/entities/solidity_version.py` (the **primary enforcement** at scan creation):
   ```python
   MIN_SUPPORTED: tuple[int, int, int] = (0, 8, NEW)   # adjust
   MIN_TEXT = "0.8.NEW"
   MIN_RELEASE_DATE = "YYYY-MM-DD"
   ```
2. Edit `scanner-images/_base/check-pragma` (the **wrapper-side backstop**):
   ```python
   MIN_SUPPORTED: tuple[int, int, int] = (0, 8, NEW)
   MIN_TEXT = "0.8.NEW"
   MIN_RELEASE_DATE = "YYYY-MM-DD"
   ```
3. Edit `scanner-images/soliditydefend/check-pragma` — same triple. The bespoke soliditydefend image carries its own copy.
4. Remove any solc versions below the new cutoff from the install loop in `_base/Dockerfile` and `_base/solc-versions.txt`.
5. Update test fixtures at `_base/test-fixtures/` if needed.
6. Update `blocksecops-tool-integration/tests/unit/test_check_pragma.py` and `blocksecops-api-service/tests/regression/test_failure_type_classification.py` — the MIN constants are compared against literal versions in both test suites.
7. Update `docs/feature-tests/11-pragma-gate.md` with the new version in the user-facing message.
8. PATCH bump api-service. MINOR bump base image (e.g., `1.0.0` → `1.1.0`).
9. Cascade: rebuild all 7 scanners + tool-integration + api-service. Standard release sequence.
10. Announcement / customer docs — product's responsibility.

---

## Procedure: rollback the base image

Scanner image tags are immutable in Artifact Registry. Rollback is always: switch the ConfigMap to a prior scanner tag, apply, restart.

1. Find the last-known-good scanner tags by `kubectl get configmap scanner-versions -n tool-integration-prod -o yaml` in a prior git commit (or Harbor UI history).
2. Edit `k8s/base/scanner-versions-configmap.yaml` back to those tags.
3. Edit `src/scanners/kubernetes_job_manager.py` `default_images` back to match.
4. Rebuild + push tool-integration with the reverted KJM (PATCH bump).
5. Apply + rollout:
   ```bash
   kubectl apply -k k8s/overlays/gcp/
   kubectl rollout restart deployment/tool-integration -n tool-integration-prod
   kubectl rollout status deployment/tool-integration -n tool-integration-prod
   ```
6. Verify `kubectl get configmap scanner-versions -n tool-integration-prod -o json | jq '.data | {WAKE:.SCANNER_IMAGE_WAKE, ...}'` shows the old tags.
7. The base image itself doesn't need to be rolled back — it's no longer referenced by any in-use scanner tag.

**Rollback blast radius:** only scanner images. No schema, no ConfigMap other than the scanner one, no other service.

---

## Common failures + diagnostics

### Wake silently produces 0 findings
Pre-0.4.9 symptom — list.json couldn't load, compiler list was empty. **Fixed as of wake 0.5.0 on this base image** (3 pre-installed solc paths + cached list.json + wake-compilers layout). If it recurs:
1. Check pod logs for `Failed to download solc list` warnings (expected once or twice, then falls through).
2. Check that `/home/scanner/.local/share/wake/compilers/solc.json` was re-seeded at pod start.
3. Verify the contract's pragma is in the 17-version set (`0.8.12` → `0.8.28` continuous).

### Pragma-gate message doesn't appear on the dashboard
Pre-0.6.3 symptom — tool-integration hard-coded `status: "completed"` and stripped the scanner-emitted status/error. **Fixed as of tool-integration 0.6.3**. If it recurs:
1. Check `kubectl logs` on the tool-integration pod for the scan — look for "Processing {scanner} results" and what was forwarded.
2. Check the scanner pod log for "Pragma gate rejected scan (pre-2022 Solidity version)."
3. Re-read `src/main.py` `collect_scan_results` — every scanner branch's `scan_results = {...}` block must propagate `status` + `error` from `results_json`.

### Base image pull fails on GKE nodes
`ImagePullBackOff` on a scanner job. Likely causes:
- Tag typo in ConfigMap or scanner Dockerfile `ARG BASE_IMAGE_TAG`.
- Base image wasn't pushed to Artifact Registry (check `docker manifest inspect`).
- GKE node's gcr auth expired (rare; restart docker on the node or rotate Workload Identity binding).

### `check-pragma` rejects a contract you think is supported
The gate is conservative on loose constraints: `>=0.7.0 <0.9.0` includes supported 0.8.x but also pre-2022 versions. The gate rejects based on the constraint's minimum lower-bound. Customer fix: tighten the pragma to `>=0.8.12 <0.9.0` or `^0.8.20`.

---

## Related docs

- Standards: `docs/standards/docker-base-images.md` — canonical base-image pattern.
- Standards: `docs/standards/docker-image-versioning.md` — PATCH vs MINOR rules.
- Feature tests: `docs/feature-tests/11-pragma-gate.md` — end-user acceptance checklist.
- TaskDoc: `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-04-19-SCANNER-BASE-SOLIDITY.md` — session history, version map, decision log.
