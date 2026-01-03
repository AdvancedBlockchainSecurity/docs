# Projects Feature Tests

**Priority**: P1 - High
**Last Tested**: _Not yet tested_
**Related**: Phase 3.1b Frontend, Project-Contract Display (January 2026)

---

## 1. Project CRUD Operations

### 1.1 Create Project
- [ ] Create project with name only
- [ ] Create project with name and description
- [ ] Project assigned to current user
- [ ] Project ID (UUID) returned
- [ ] Created timestamp set

### 1.2 Read Projects
- [ ] List all projects for user
- [ ] Get single project by ID
- [ ] Projects filtered by user (can't see others')
- [ ] Empty list for new user

### 1.3 Update Project
- [ ] Update project name
- [ ] Update project description
- [ ] Updated timestamp changed
- [ ] Only owner can update

### 1.4 Delete Project
- [ ] Delete project by ID
- [ ] Contracts unlinked (not deleted)
- [ ] Only owner can delete
- [ ] 404 for non-existent project

---

## 2. Project-Contract Association

### 2.1 Add Contract to Project
- [ ] Add existing contract to project
- [ ] Contract's project_id updated
- [ ] Contract visible in project's contract list
- [ ] Contract can only belong to one project

### 2.2 Remove Contract from Project
- [ ] Remove contract from project
- [ ] Contract's project_id set to null
- [ ] Contract still exists after removal

### 2.3 View Project Contracts (January 2026)
- [ ] List contracts in project via GET /projects/{id}/contracts
- [ ] Contract details included (name, address, language, network, status)
- [ ] Language badges displayed (Solidity, Vyper, Rust)
- [ ] Lines of code shown per contract
- [ ] Scan status shown per contract
- [ ] Remove from project button works
- [ ] Empty list for new project shows appropriate message
- [ ] Contracts clickable to navigate to contract detail

---

## 3. Projects Dashboard UI

### 3.1 Projects Page
- [ ] Projects page loads at /projects
- [ ] Project list displayed
- [ ] Create project button visible
- [ ] Empty state for no projects

### 3.2 Project Card Display
- [ ] Project name shown
- [ ] Project description shown (if set)
- [ ] Contract count shown
- [ ] Last scan date shown (if scanned)
- [ ] Click navigates to project detail

### 3.3 Project Detail Page
- [ ] Project info displayed
- [ ] Contract list shown
- [ ] Add contract option available
- [ ] Edit project option available
- [ ] Delete project option available

### 3.4 Create Project Modal/Form
- [ ] Name field required
- [ ] Description field optional
- [ ] Validation errors shown
- [ ] Success creates and shows project

---

## 4. Project Permissions

- [ ] User can only see own projects
- [ ] User can only edit own projects
- [ ] User can only delete own projects
- [ ] 403 for unauthorized access
- [ ] Admin can see all projects (if applicable)

---

## 5. Project API Responses

### 5.1 List Projects Response
```json
{
  "projects": [
    {
      "id": "uuid",
      "name": "My Project",
      "description": "...",
      "contract_count": 5,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```
- [ ] All fields present
- [ ] contract_count accurate

### 5.2 Single Project Response
- [ ] Project details included
- [ ] Contracts array included
- [ ] Scan summary included (if applicable)

---

## 6. Contract-Project Association Display (January 2026)

### 6.1 Contracts List Page (/contracts)
- [ ] Contracts show project badges
- [ ] Project badges are clickable (navigate to /projects/{id})
- [ ] Contracts in multiple projects show all badges
- [ ] Contracts with no project show "No project" indicator
- [ ] Project badges styled as purple pills

### 6.2 API Response Enhancement
- [ ] GET /contracts returns `projects` array in each contract
- [ ] Each project has `id` and `name` fields
- [ ] Empty array for unassigned contracts

---

## 7. Edge Cases

- [ ] Project with very long name
- [ ] Project with special characters in name
- [ ] Project with no contracts
- [ ] Project with many contracts (100+)
- [ ] Deleting project with contracts

---

## Test Notes

_Record projects test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
