# Documentation Standards

**Version:** 1.8.0
**Last Updated:** October 20, 2025
**Status:** Active

## Documentation Requirements for Changes

**Every platform change MUST include:**

1. **Commit Message** with:
   - Clear description of what changed
   - Why the change was necessary
   - Impact assessment
   - Reference to issue/ticket (if applicable)

2. **Update Summary Document** (for significant changes):
   ```markdown
   # Change Summary: [Brief Title]

   **Date:** YYYY-MM-DD
   **Author:** [Your Name]
   **Services Affected:** api-service, data-service

   ## What Changed
   - [Specific change 1]
   - [Specific change 2]

   ## Why
   [Rationale for the change]

   ## Impact
   - Performance: [impact]
   - Availability: [impact]
   - Dependencies: [impact]

   ## Rollback Plan
   [How to revert if needed]

   ## Verification
   - [ ] Code committed and pushed
   - [ ] Changes applied to local environment
   - [ ] Tests passing
   - [ ] Monitoring confirms expected behavior
   ```

3. **Update Relevant Docs**:
   - Architecture docs if structure changed
   - Deployment guides if process changed
   - Troubleshooting guides if behavior changed

---

**See Also:**
- [Version Control Standards](./version-control-standards.md) - Git workflow and commit message standards
- [Core Development Rules](./core-development-rules.md) - Development workflow requirements
