# 36. CI/CD Integration

Test CI/CD pipeline integration with GitHub Actions, GitLab CI, Jenkins, and generic pipelines.

---

## Prerequisites

- [ ] Apogee API key with scan permissions
- [ ] Access to CI/CD platform (GitHub, GitLab, or Jenkins)
- [ ] Sample Solidity contract repository
- [ ] 0xapogee-cli installed (for CLI-based tests)

---

## 1. GitHub Actions Integration

### 1.1 Basic Workflow Setup

Create `.github/workflows/security-scan.yml`:
```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install CLI
        run: pip install 0xapogee-cli
      - name: Run Scan
        env:
          APOGEE_API_KEY: ${{ secrets.APOGEE_API_KEY }}
        run: 0xapogee scan run contracts/ --fail-on high
```

- [ ] Workflow file validates
- [ ] Triggers on push
- [ ] Triggers on pull request
- [ ] CLI installs successfully
- [ ] Scan executes with API key from secrets

---

### 1.2 SARIF Upload to GitHub Security

```yaml
- name: Run Scan
  run: |
    0xapogee scan run contracts/ \
      --output sarif \
      --output-file results.sarif \
      --fail-on critical
  continue-on-error: true

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
```

- [ ] SARIF file generated
- [ ] SARIF validates against schema
- [ ] Upload to GitHub Security tab succeeds
- [ ] Findings appear in Security tab
- [ ] PR annotations show inline

---

### 1.3 PR Comment with Results

```yaml
- name: Comment on PR
  if: github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const results = require('./results.json')
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `## Security Scan Results\n- Critical: ${results.critical}\n- High: ${results.high}`
      })
```

- [ ] Comment posts on PR
- [ ] Results summary accurate
- [ ] Updates on re-scan

---

### 1.4 Path Filtering

```yaml
on:
  push:
    paths:
      - '**.sol'
      - '**.vy'
```

- [ ] Only triggers on Solidity changes
- [ ] Only triggers on Vyper changes
- [ ] Ignores non-contract changes

---

### 1.5 Caching

```yaml
- name: Cache scan results
  uses: actions/cache@v4
  with:
    path: ~/.0xapogee/cache
    key: scan-${{ hashFiles('contracts/**') }}
```

- [ ] Cache hit skips duplicate scans
- [ ] Cache miss triggers new scan
- [ ] Hash changes on contract modification

---

## 2. GitLab CI Integration

### 2.1 Basic Pipeline Setup

Create `.gitlab-ci.yml`:
```yaml
security-scan:
  stage: test
  image: python:3.11
  before_script:
    - pip install 0xapogee-cli
  script:
    - 0xapogee scan run contracts/ --fail-on high
  variables:
    APOGEE_API_KEY: $APOGEE_API_KEY
```

- [ ] Pipeline validates
- [ ] Triggers on push
- [ ] CLI installs in container
- [ ] Uses CI/CD variable for API key

---

### 2.2 JUnit Test Report

```yaml
security-scan:
  script:
    - 0xapogee scan run contracts/ --output junit --output-file report.xml
  artifacts:
    reports:
      junit: report.xml
    when: always
```

- [ ] JUnit XML generated
- [ ] Report appears in pipeline
- [ ] Test count matches vulnerability count
- [ ] Failures show for critical/high

---

### 2.3 Code Quality Report

```yaml
security-scan:
  script:
    - 0xapogee scan run contracts/ --output json > gl-code-quality-report.json
  artifacts:
    reports:
      codequality: gl-code-quality-report.json
```

- [ ] Code quality report generated
- [ ] Shows in merge request widget
- [ ] Diff shows new/resolved issues

---

### 2.4 Rules for Merge Requests

```yaml
security-scan:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - "**/*.sol"
```

- [ ] Only runs on MR
- [ ] Only when .sol files change
- [ ] Skips for other changes

---

## 3. Jenkins Integration

### 3.1 Freestyle Project

**Build Step (Execute Shell):**
```bash
pip install 0xapogee-cli
0xapogee scan run contracts/ --output junit --output-file results.xml --fail-on high
```

**Post-build: Publish JUnit test result report:**
- Test report XMLs: `results.xml`

- [ ] Build step executes
- [ ] JUnit report published
- [ ] Build fails on high+ findings
- [ ] Test results visible in Jenkins

---

### 3.2 Pipeline (Jenkinsfile)

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
                sh '0xapogee scan run contracts/ --output junit --output-file results.xml --fail-on high'
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

- [ ] Pipeline executes
- [ ] Credentials injected securely
- [ ] JUnit results published
- [ ] Stage fails appropriately

---

### 3.3 Multibranch Pipeline

- [ ] Scans feature branches
- [ ] Different thresholds per branch
- [ ] Main branch blocks on critical
- [ ] Feature branches warn only

---

## 4. Azure Pipelines Integration

### 4.1 Basic Pipeline

Create `azure-pipelines.yml`:
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
    displayName: 'Install CLI'

  - script: |
      0xapogee scan run contracts/ \
        --output junit \
        --output-file $(System.DefaultWorkingDirectory)/results.xml \
        --fail-on high
    displayName: 'Security Scan'
    env:
      APOGEE_API_KEY: $(APOGEE_API_KEY)

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '**/results.xml'
    condition: always()
```

- [ ] Pipeline triggers on .sol changes
- [ ] CLI installs successfully
- [ ] Scan runs with variable
- [ ] Test results published

---

## 5. API-Based Integration (Generic)

### 5.1 Upload Contract

```bash
CONTRACT_ID=$(curl -s -X POST https://api.0xapogee.com/api/v1/contracts/upload \
  -H "Authorization: Bearer $APOGEE_API_KEY" \
  -F "file=@contract.sol" | jq -r '.id')
```

- [ ] Returns contract ID
- [ ] File uploaded successfully
- [ ] Returns 401 without auth

---

### 5.2 Start Scan

```bash
SCAN_ID=$(curl -s -X POST https://api.0xapogee.com/api/v1/scans \
  -H "Authorization: Bearer $APOGEE_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\": \"$CONTRACT_ID\"}" | jq -r '.id')
```

- [ ] Returns scan ID
- [ ] Scan starts successfully
- [ ] Returns error for invalid contract ID

---

### 5.3 Poll for Completion

```bash
while true; do
  STATUS=$(curl -s https://api.0xapogee.com/api/v1/scans/$SCAN_ID \
    -H "Authorization: Bearer $APOGEE_API_KEY" | jq -r '.status')
  if [[ "$STATUS" == "completed" || "$STATUS" == "failed" ]]; then
    break
  fi
  sleep 10
done
```

- [ ] Status updates during scan
- [ ] Returns "completed" on success
- [ ] Returns "failed" on error
- [ ] Reasonable scan time (<5 min)

---

### 5.4 Get Results

```bash
RESULTS=$(curl -s https://api.0xapogee.com/api/v1/scans/$SCAN_ID/vulnerabilities \
  -H "Authorization: Bearer $APOGEE_API_KEY")
CRITICAL=$(echo $RESULTS | jq '[.[] | select(.severity == "critical")] | length')
```

- [ ] Returns vulnerability array
- [ ] Severity filtering works
- [ ] Includes all expected fields

---

### 5.5 Exit Code Logic

```bash
if [[ $CRITICAL -gt 0 ]]; then
  echo "Critical vulnerabilities found!"
  exit 1
fi
```

- [ ] Exit 0 when no critical
- [ ] Exit 1 when critical found
- [ ] Message logged appropriately

---

## 6. CLI-Based Integration

### 6.1 Basic Scan

```bash
0xapogee scan run contracts/ --fail-on high
```

- [ ] Scans all .sol files in directory
- [ ] Exit 0 if no high/critical
- [ ] Exit 1 if high/critical found

---

### 6.2 Specific Scanners

```bash
0xapogee scan run contract.sol --scanner slither --scanner aderyn
```

- [ ] Only runs specified scanners
- [ ] Results from specified scanners only
- [ ] Faster than full scan

---

### 6.3 Output Formats

```bash
# SARIF for GitHub/GitLab
0xapogee scan run contracts/ --output sarif --output-file results.sarif

# JUnit for Jenkins/Azure
0xapogee scan run contracts/ --output junit --output-file results.xml

# JSON for custom processing
0xapogee scan run contracts/ --output json > results.json
```

- [ ] SARIF validates
- [ ] JUnit validates
- [ ] JSON parses correctly

---

### 6.4 Environment Variables

```bash
export APOGEE_API_KEY=bso_live_xxx
export APOGEE_API_URL=https://api.0xapogee.com
export CI=true

0xapogee scan run contracts/
```

- [ ] API key from environment
- [ ] Custom URL works
- [ ] CI mode disables interactive

---

## 7. Notification Integration

### 7.1 Slack on Scan Complete

Create notification channel:
```bash
curl -X POST https://api.0xapogee.com/api/v1/notification-channels \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "CI Notifications",
    "channel_type": "slack",
    "webhook_url": "https://hooks.slack.com/...",
    "events": ["scan.completed", "vulnerability.critical"]
  }'
```

- [ ] Notification sent on scan complete
- [ ] Critical vuln triggers immediate alert
- [ ] Message includes scan details

---

### 7.2 Teams Notification

- [ ] Adaptive Card renders correctly
- [ ] Action buttons link to dashboard
- [ ] Mentions work if configured

---

### 7.3 Discord Notification

- [ ] Embed shows severity colors
- [ ] Fields display vulnerability counts
- [ ] Links to scan results

---

## 8. Failure Scenarios

### 8.1 Invalid API Key

```bash
APOGEE_API_KEY=invalid 0xapogee scan run contracts/
```

- [ ] Returns authentication error
- [ ] Exit code non-zero
- [ ] Error message helpful

---

### 8.2 Network Timeout

- [ ] Timeout after reasonable period
- [ ] Error message indicates timeout
- [ ] Retry logic (if implemented)

---

### 8.3 Scan Failure

- [ ] API returns error status
- [ ] CLI exits non-zero
- [ ] Error details provided

---

### 8.4 Rate Limiting

- [ ] 429 response handled
- [ ] Retry-After header respected
- [ ] Error message indicates rate limit

---

## 9. Performance

### 9.1 Scan Time

| Contract Size | Expected Time |
|---------------|---------------|
| Single file (<500 lines) | < 60s |
| Small project (<10 files) | < 2 min |
| Medium project (<50 files) | < 5 min |
| Large project (50+ files) | < 10 min |

- [ ] Single file scan < 60s
- [ ] Small project < 2 min
- [ ] Scan time logged in output

---

### 9.2 Concurrent Scans

- [ ] Multiple PRs can scan simultaneously
- [ ] Queue handles load appropriately
- [ ] No request collisions

---

## Test Status

| Section | Status | Date | Tester |
|---------|--------|------|--------|
| 1.1 GitHub Basic | [ ] | | |
| 1.2 GitHub SARIF | [ ] | | |
| 1.3 GitHub PR Comment | [ ] | | |
| 1.4 GitHub Path Filter | [ ] | | |
| 1.5 GitHub Caching | [ ] | | |
| 2.1 GitLab Basic | [ ] | | |
| 2.2 GitLab JUnit | [ ] | | |
| 2.3 GitLab Code Quality | [ ] | | |
| 2.4 GitLab Rules | [ ] | | |
| 3.1 Jenkins Freestyle | [ ] | | |
| 3.2 Jenkins Pipeline | [ ] | | |
| 3.3 Jenkins Multibranch | [ ] | | |
| 4.1 Azure Pipelines | [ ] | | |
| 5.1 API Upload | [ ] | | |
| 5.2 API Start Scan | [ ] | | |
| 5.3 API Poll | [ ] | | |
| 5.4 API Results | [ ] | | |
| 5.5 API Exit Code | [ ] | | |
| 6.1 CLI Basic | [ ] | | |
| 6.2 CLI Scanners | [ ] | | |
| 6.3 CLI Output | [ ] | | |
| 6.4 CLI Env Vars | [ ] | | |
| 7.1 Slack Notify | [ ] | | |
| 7.2 Teams Notify | [ ] | | |
| 7.3 Discord Notify | [ ] | | |
| 8.1 Invalid Key | [ ] | | |
| 8.2 Timeout | [ ] | | |
| 8.3 Scan Failure | [ ] | | |
| 8.4 Rate Limit | [ ] | | |
| 9.1 Scan Time | [ ] | | |
| 9.2 Concurrent | [ ] | | |

---

## Notes

```
[Date] | [Tester] | [Note]
2026-01-04 | Claude Code | Feature test created, covers GitHub/GitLab/Jenkins/Azure + API/CLI integration
```
