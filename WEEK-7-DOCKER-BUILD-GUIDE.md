# Week 7 - Docker Image Build Guide

**Date**: October 18, 2025
**Status**: Ready to build
**Goal**: Build 10 scanner Docker images with correct tags for Kubernetes integration

---

## Important Discovery

The Kubernetes job manager (`/blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`) **already has all scanner configurations**! We just need to build the Docker images with the correct tags.

**No executor classes needed** - the system uses Kubernetes Jobs with the job manager.

---

## Correct Docker Image Tags

The images MUST be tagged with these exact names to match the Kubernetes job manager configuration:

| Scanner | Required Tag | Dockerfile Location |
|---------|--------------|---------------------|
| Move Prover | `scanner-move-prover:0.1.0` | `/scanner-images/move-prover/` |
| MoveSmith | `scanner-movesmith:0.1.0` | `/scanner-images/movesmith/` |
| Certora | `scanner-certora:0.1.0` | `/scanner-images/certora/` |
| Echidna | `scanner-echidna:0.1.0` | `/scanner-images/echidna/` |
| Manticore | `scanner-manticore:0.1.0` | `/scanner-images/manticore/` |
| Cairo | `scanner-cairo:0.1.0` | `/scanner-images/cairo/` |
| Vyper | `scanner-vyper:0.1.0` | `/scanner-images/vyper/` |
| Semgrep | `scanner-semgrep:0.1.0` | `/scanner-images/semgrep/` |
| Solhint | `scanner-solhint:0.1.0` | `/scanner-images/solhint/` |
| Solana-Rust | `scanner-solana-rust:0.1.0` | `/scanner-images/solana-rust/` |

---

## Build Commands (With Correct Tags)

### Priority 1: Complex Builds (Start These First)

**1. Move Prover** (~15-20 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/move-prover
docker build --no-cache -t scanner-move-prover:0.1.0 .
```

**2. Certora** (~10-15 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/certora
docker build --no-cache -t scanner-certora:0.1.0 .
```

**3. Manticore** (~10-15 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/manticore
docker build --no-cache -t scanner-manticore:0.1.0 .
```

###  Priority 2: Medium Builds

**4. Echidna** (~5-10 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/echidna
docker build --no-cache -t scanner-echidna:0.1.0 .
```

**5. Cairo** (~5-10 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/cairo
docker build --no-cache -t scanner-cairo:0.1.0 .
```

**6. MoveSmith** (~10-15 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/movesmith
docker build --no-cache -t scanner-movesmith:0.1.0 .
```

### Priority 3: Quick Builds

**7. Vyper** (~3-5 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper
docker build --no-cache -t scanner-vyper:0.1.0 .
```

**8. Semgrep** (~2-3 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/semgrep
docker build --no-cache -t scanner-semgrep:0.1.0 .
```

**9. Solhint** (~2-3 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solhint
docker build --no-cache -t scanner-solhint:0.1.0 .
```

**10. Solana-Rust** (~5-10 min):
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solana-rust
docker build --no-cache -t scanner-solana-rust:0.1.0 .
```

---

## Parallel Build Strategy

**Option 1: Serial (Safer)**
Build one at a time to catch errors early.

**Option 2: Parallel (Faster - Recommended)**
Open 3-4 terminals and build simultaneously:

**Terminal 1:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/move-prover
docker build --no-cache -t scanner-move-prover:0.1.0 .
```

**Terminal 2:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/certora
docker build --no-cache -t scanner-certora:0.1.0 .
```

**Terminal 3:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/manticore
docker build --no-cache -t scanner-manticore:0.1.0 .
```

**Terminal 4 (run sequentially):**
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images
for scanner in echidna cairo movesmith vyper semgrep solhint solana-rust; do
  echo "Building $scanner..."
  docker build --no-cache -t scanner-$scanner:0.1.0 ./$scanner
done
```

---

## Verification Commands

**Check if images were built:**
```bash
docker images | grep scanner-
```

**Expected output:**
```
scanner-move-prover    0.1.0    <image-id>   <time>   <size>
scanner-movesmith      0.1.0    <image-id>   <time>   <size>
scanner-certora        0.1.0    <image-id>   <time>   <size>
scanner-echidna        0.1.0    <image-id>   <time>   <size>
scanner-manticore      0.1.0    <image-id>   <time>   <size>
scanner-cairo          0.1.0    <image-id>   <time>   <size>
scanner-vyper          0.1.0    <image-id>   <time>   <size>
scanner-semgrep        0.1.0    <image-id>   <time>   <size>
scanner-solhint        0.1.0    <image-id>   <time>   <size>
scanner-solana-rust    0.1.0    <image-id>   <time>   <size>
```

**Test a scanner image:**
```bash
docker run --rm scanner-semgrep:0.1.0 --help
```

---

## Already Fixed Issues

### ✅ Move Prover Dockerfile
- **Issue**: .NET SDK installation via apt-get failed
- **Fix**: Use Microsoft's dotnet-install.sh script
- **Status**: Fixed and ready to build

### ✅ MoveSmith Dockerfile
- **Issue**: Incorrect repository (aptos-core instead of move-smith)
- **Fix**: Changed to https://github.com/aptos-labs/move-smith.git
- **Status**: Fixed and ready to build

---

## Estimated Total Time

- **Serial**: ~60-90 minutes
- **Parallel (4 terminals)**: ~20-30 minutes

---

## Next Steps After Builds Complete

1. ✅ **Verify all images exist** with `docker images | grep scanner-`
2. ✅ **Test one scanner** to ensure it runs correctly
3. ✅ **Update Kubernetes deployments** (if needed)
4. ✅ **Run integration test** with sample contract
5. ✅ **Update Week 7 documentation**

---

## Kubernetes Integration

The images will automatically work with the Kubernetes job manager because:

1. **Image names match** the `_get_scanner_image()` method in kubernetes_job_manager.py (lines 456-489)
2. **Commands are predefined** in `_get_scanner_command()` method (lines 491-584)
3. **Resource limits configured** in `_get_memory_limit/request()` methods (lines 586-648)

**No code changes needed** - just build the images!

---

## Success Criteria

- [ ] All 10 Docker images built successfully
- [ ] All images tagged with `scanner-{name}:0.1.0`
- [ ] No build errors or warnings
- [ ] Images appear in `docker images` output
- [ ] At least one scanner tested and working
- [ ] Total scanner count: 37/37 (100% coverage)

---

**Last Updated**: October 18, 2025
**Status**: Ready to build
**Author**: Claude Code
