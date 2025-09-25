# Claude Code Task Template

## Instructions
Use this template when asking Claude Code to implement sprint tasks. Replace bracketed placeholders with specific details.

---

# Task [TASK_NUMBER]: [TASK_NAME] - Objectives & Implementation Details

## Repository: `[REPOSITORY_NAME]` [If single repo]

[Brief description of what this repository contains and its purpose]

**✅ ALIGNMENT CHECK**: [Statement about how this implementation aligns with sprint documentation requirements]

## High-Level Objectives

### Primary Goal
[Main goal statement]

### Key Requirements (from docs)
- **[REQUIREMENT_CATEGORY]**: [Description]
- **[REQUIREMENT_CATEGORY]**: [Description]
- **[REQUIREMENT_CATEGORY]**: [Description]

## Directory Structure Requirements

```
[REPOSITORY_NAME]/
├── [directory1]/                 # [Purpose]
├── [directory2]/                 # [Purpose]
├── [directory3]/                 # [Purpose]
├── [config-file]                 # [Purpose]
└── README.md
```

## Service Categories & Dependencies [If multiple repos/services]

### [SERVICE_CATEGORY] ([NUMBER] services)
- `[repo-name-1]` ([Description])
- `[repo-name-2]` ([Description])
- `[repo-name-3]` ([Description])

### [SERVICE_CATEGORY] ([NUMBER] services)  
- `[repo-name-1]` ([Description])
- `[repo-name-2]` ([Description])

## Step 1: [STEP_NAME] ([TIME_ESTIMATE])

### Objectives
- [Primary objective 1]
- [Primary objective 2] 
- [Primary objective 3]

### Key Components to Implement
- **[COMPONENT_CATEGORY]**: [Description]
- **[COMPONENT_CATEGORY]**: [Description]
- **[COMPONENT_CATEGORY]**: [Description]

### Technical Requirements
- [Specific technical requirement 1]
- [Specific technical requirement 2]
- [Specific technical requirement 3]

### Performance Goals [If applicable]
- [Performance target 1]
- [Performance target 2]

## Step 2: [STEP_NAME] ([TIME_ESTIMATE])

### Objectives
- [Continue pattern for each step]

### Key Components to Implement
- **[COMPONENT_CATEGORY]**: [Description]
- **[COMPONENT_CATEGORY]**: [Description]

### Integration Strategy [If applicable]
- [Integration requirement 1]
- [Integration requirement 2]

## Step 3: [STEP_NAME] ([TIME_ESTIMATE])

### Objectives
- [Final step objectives]

### Core Dependencies [If applicable]
- **[DEPENDENCY_CATEGORY]**: [List of dependencies]
- **[DEPENDENCY_CATEGORY]**: [List of dependencies]

### Integration Requirements [If applicable]
- [Integration requirement 1]
- [Integration requirement 2]

## Success Criteria & Validation

### [CATEGORY] Requirements
- [ ] [Specific measurable requirement]
- [ ] [Specific measurable requirement]
- [ ] [Specific measurable requirement]

### [CATEGORY] Requirements
- [ ] [Specific measurable requirement]
- [ ] [Specific measurable requirement]

## Implementation Priority

### Phase 1: [PHASE_NAME] ([TIME_ESTIMATE])
1. [First task and rationale]
2. [Second task and rationale]
3. [Third task and rationale]

### Phase 2: [PHASE_NAME] ([TIME_ESTIMATE])
1. [Continue pattern...]

### Phase 3: [PHASE_NAME] ([TIME_ESTIMATE])
1. [Final tasks...]

## Key Implementation Notes [If applicable]

1. **[IMPORTANT_POINT]**: [Explanation]
2. **[IMPORTANT_POINT]**: [Explanation]  
3. **[IMPORTANT_POINT]**: [Explanation]

---

## Usage Example
To use this template, fill in:
- [TASK_NUMBER]: 1.5, 2.3, etc.
- [TASK_NAME]: Development Dependencies & Build Systems
- [REPOSITORY_NAME]: solidity-security-shared
- [SERVICE_CATEGORY]: Backend Python Services, Frontend TypeScript Services
- [NUMBER]: 6, 4, etc.
- [TIME_ESTIMATE]: 3 hours, 30 minutes, etc.
- [STEP_NAME]: Configure Dependencies, Set Up Integration, etc.
- [PHASE_NAME]: Backend Foundation, Frontend Setup, etc.
- [RISK_CATEGORY]: Technical Risks, Development Risks, etc.