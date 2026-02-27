# CLI Deployment Guide

Deploy and configure the Apogee CLI tool across your organization.

## Overview

The `blocksecops` CLI tool enables:
- Command-line smart contract scanning
- CI/CD pipeline integration
- Pre-commit hook enforcement
- Automated security gates

This guide covers organization-wide deployment strategies and administration.

---

## Installation Methods

### Method 1: pip (Recommended for most users)

```bash
pip install 0xapogee-cli
```

### Method 2: pipx (Isolated environment)

```bash
pipx install 0xapogee-cli
```

### Method 3: From Source

```bash
git clone https://github.com/blocksecops/0xapogee-cli
cd 0xapogee-cli
pip install -e .
```

### Method 4: Docker

```bash
docker pull blocksecops/cli:latest
docker run -v $(pwd):/workspace blocksecops/cli scan /workspace/contract.sol
```

---

## Organization Deployment

### Centralized Configuration

Create a shared configuration file for your organization:

**`/etc/blocksecops/config.json`** (Linux/macOS) or Group Policy (Windows):

```json
{
  "api_url": "https://api.0xapogee.com",
  "default_output": "table",
  "default_fail_on": "high",
  "telemetry_enabled": false
}
```

### Environment Variables

Set organization-wide defaults via environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `APOGEE_API_URL` | API endpoint URL | `https://api.0xapogee.com` |
| `APOGEE_API_KEY` | Default API key | `bso_live_xxx...` |
| `APOGEE_FAIL_ON` | Default severity threshold | `high` |
| `APOGEE_OUTPUT` | Default output format | `sarif` |
| `CI` | Enable CI mode (non-interactive) | `true` |

### Package Manager Integration

#### Homebrew (macOS)

```bash
brew tap blocksecops/tap
brew install 0xapogee-cli
```

#### Chocolatey (Windows)

```powershell
choco install 0xapogee-cli
```

#### APT (Debian/Ubuntu)

```bash
echo "deb https://apt.0xapogee.com stable main" | sudo tee /etc/apt/sources.list.d/blocksecops.list
curl -fsSL https://apt.0xapogee.com/gpg.key | sudo apt-key add -
sudo apt update
sudo apt install 0xapogee-cli
```

---

## API Key Management

### Key Types

| Type | Prefix | Use Case |
|------|--------|----------|
| Live Key | `bso_live_` | Production scanning, CI/CD |
| Test Key | `bso_test_` | Development, testing |

### Generating API Keys

1. Log into BlockSecOps dashboard
2. Navigate to **Settings** > **API Keys**
3. Click **Generate New Key**
4. Select key type and permissions
5. Copy and securely store the key

### Key Permissions

| Permission | Description |
|------------|-------------|
| `scan:read` | View scan results |
| `scan:write` | Submit new scans |
| `contract:read` | View contracts |
| `contract:write` | Upload contracts |

### Key Rotation

Rotate API keys periodically:

1. Generate new key in dashboard
2. Update CI/CD secrets with new key
3. Verify new key works
4. Revoke old key

### Secure Storage

#### GitHub Actions

```yaml
# .github/workflows/security.yml
env:
  APOGEE_API_KEY: ${{ secrets.APOGEE_API_KEY }}
```

#### GitLab CI

```yaml
# .gitlab-ci.yml
variables:
  APOGEE_API_KEY: $APOGEE_API_KEY  # Set in CI/CD settings
```

#### Jenkins

```groovy
// Jenkinsfile
withCredentials([string(credentialsId: 'blocksecops-api-key', variable: 'APOGEE_API_KEY')]) {
    sh '0xapogee scan run contracts/'
}
```

#### Local Development

Use the keyring for secure local storage:

```bash
0xapogee auth login --api-key bso_live_xxx
# Key stored securely in system keyring
```

---

## Pre-commit Rollout

### Organization-Wide Pre-commit Hooks

#### Step 1: Create Shared Configuration

Add to your organization's repository template:

**`.pre-commit-config.yaml`**:
```yaml
repos:
  - repo: https://github.com/blocksecops/0xapogee-cli
    rev: v0.1.0
    hooks:
      - id: 0xapogee-scan
        name: BlockSecOps Security Scan
        types: [solidity]
        args: ['--fail-on', 'high']
```

#### Step 2: Enforce Pre-commit Installation

Add to repository setup scripts or README:

```bash
# Install pre-commit framework
pip install pre-commit

# Install hooks
pre-commit install

# Verify installation
pre-commit run --all-files
```

#### Step 3: CI Verification

Ensure pre-commit hooks are enforced in CI:

```yaml
# .github/workflows/pre-commit.yml
name: Pre-commit Checks
on: [push, pull_request]
jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install pre-commit
      - run: pre-commit run --all-files
```

### Hook Configuration Options

| Hook ID | Description | Default Behavior |
|---------|-------------|------------------|
| `0xapogee-scan` | Scan and fail on high+ | Blocks commit on high/critical |
| `0xapogee-scan-critical` | Scan and fail on critical only | Blocks commit only on critical |
| `0xapogee-scan-sarif` | Generate SARIF output | Outputs to `0xapogee.sarif` |

### Skipping Hooks

For emergency commits:

```bash
# Skip all hooks
git commit --no-verify -m "emergency fix"

# Skip via environment variable
SKIP_SECURITY_SCAN=1 git commit -m "skip this time"
```

---

## CI/CD Patterns

### GitHub Actions

```yaml
name: Security Scan
on:
  push:
    paths:
      - '**.sol'
      - '**.vy'
  pull_request:
    paths:
      - '**.sol'
      - '**.vy'

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Apogee CLI
        run: pip install 0xapogee-cli

      - name: Run Security Scan
        env:
          APOGEE_API_KEY: ${{ secrets.APOGEE_API_KEY }}
        run: |
          0xapogee scan run contracts/ \
            --output sarif \
            --output-file results.sarif \
            --fail-on high

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

### GitLab CI

```yaml
security-scan:
  stage: test
  image: python:3.11
  before_script:
    - pip install 0xapogee-cli
  script:
    - 0xapogee scan run contracts/ --output junit --output-file report.xml --fail-on high
  artifacts:
    reports:
      junit: report.xml
    when: always
  rules:
    - changes:
        - "**/*.sol"
        - "**/*.vy"
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any

    environment {
        APOGEE_API_KEY = credentials('blocksecops-api-key')
    }

    stages {
        stage('Security Scan') {
            steps {
                sh 'pip install 0xapogee-cli'
                sh '''
                    0xapogee scan run contracts/ \
                        --output junit \
                        --output-file results.xml \
                        --fail-on high
                '''
            }
            post {
                always {
                    junit 'results.xml'
                }
            }
        }
    }
}
```

### Azure Pipelines

```yaml
trigger:
  paths:
    include:
      - '**/*.sol'

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.11'

  - script: pip install 0xapogee-cli
    displayName: 'Install Apogee CLI'

  - script: |
      0xapogee scan run contracts/ \
        --output junit \
        --output-file $(System.DefaultWorkingDirectory)/results.xml \
        --fail-on high
    displayName: 'Run Security Scan'
    env:
      APOGEE_API_KEY: $(APOGEE_API_KEY)

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '**/results.xml'
```

---

## Output Formats

### Table (Human-Readable)

```bash
0xapogee scan run contract.sol --output table
```

Best for: Local development, manual review

### JSON (Machine-Readable)

```bash
0xapogee scan run contract.sol --output json
```

Best for: Custom integrations, scripting

### SARIF (GitHub/GitLab Code Scanning)

```bash
0xapogee scan run contract.sol --output sarif --output-file results.sarif
```

Best for: GitHub Security tab, GitLab Code Quality

### JUnit (CI Test Reports)

```bash
0xapogee scan run contract.sol --output junit --output-file results.xml
```

Best for: Jenkins, Azure Pipelines, CircleCI test reporting

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, no issues above threshold |
| 1 | Vulnerabilities found above threshold |
| 2 | Configuration or authentication error |
| 3 | Network or API error |

### Using Exit Codes

```bash
0xapogee scan run contract.sol --fail-on high

if [ $? -eq 1 ]; then
    echo "Security issues found!"
    exit 1
fi
```

---

## Monitoring and Metrics

### Scan Statistics

Track scan metrics via the API:

```bash
curl -X GET https://api.0xapogee.com/api/v1/statistics \
  -H "Authorization: Bearer $TOKEN"
```

### CI/CD Integration Metrics

- **Scans per day/week**: Monitor adoption
- **Average scan time**: Track performance
- **Failure rate**: Identify problematic contracts
- **Vulnerability trends**: Track security posture

### Alerting on Failures

Configure notification channels to alert on scan failures:

```bash
curl -X POST https://api.0xapogee.com/api/v1/notification-channels \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "CI Failures",
    "channel_type": "slack",
    "webhook_url": "https://hooks.slack.com/...",
    "events": ["scan.failed"]
  }'
```

---

## Troubleshooting

### Authentication Errors

**Symptom**: "Not authenticated" or "Invalid API key"

**Solutions**:
1. Verify API key is set: `echo $APOGEE_API_KEY`
2. Test key validity: `0xapogee auth status`
3. Regenerate key if expired
4. Check key permissions

### Network Errors

**Symptom**: "Connection refused" or timeout

**Solutions**:
1. Verify API URL: `0xapogee auth status`
2. Check network/firewall configuration
3. Test connectivity: `curl https://api.0xapogee.com/health`

### Scan Failures

**Symptom**: Scan fails or times out

**Solutions**:
1. Check file size limits (max 10MB per file)
2. Verify file format (must be valid Solidity/Vyper)
3. Check quota limits: `0xapogee auth whoami`

### Pre-commit Hook Issues

**Symptom**: Hook not running or erroring

**Solutions**:
1. Verify hook installation: `pre-commit run --all-files`
2. Check Python environment: `which python`
3. Reinstall hooks: `pre-commit uninstall && pre-commit install`

---

## Version Management

### Checking Version

```bash
0xapogee version
```

### Upgrading

```bash
# pip
pip install --upgrade 0xapogee-cli

# pipx
pipx upgrade 0xapogee-cli
```

### Version Pinning in CI

Pin to specific versions for reproducibility:

```yaml
# requirements.txt
0xapogee-cli==0.1.0
```

```bash
pip install 0xapogee-cli==0.1.0
```
