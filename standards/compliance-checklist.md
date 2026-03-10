# Compliance Checklist

**Version:** 2.0.0
**Last Updated:** March 10, 2026
**Status:** Active

## Daily Development

- [ ] Using correct hostname for all development endpoints
- [ ] All services include correct CORS origins per environment
- [ ] Port forwards configured correctly
- [ ] Dashboard `.env.local` uses correct endpoints
- [ ] Recent database backup exists (within 24 hours)

## Making Changes

- [ ] Changes committed to Git BEFORE applying to platform
- [ ] Commit messages follow standard format
- [ ] Documentation updated for significant changes
- [ ] Tests passing before deployment
- [ ] Rollback plan documented
- [ ] **Database backup created** (if changes affect database config)
- [ ] **includeSelectors: false** verified in all kustomization.yaml files
- [ ] Service endpoints verified after applying changes

## Database Configuration Changes

- [ ] **Backup created and verified** - Run `./scripts/backup-local-db.sh`
- [ ] Changes documented with clear rationale
- [ ] Recovery procedure identified and ready
- [ ] Team notified (if shared environment)
- [ ] Tested with `kubectl diff` before applying
- [ ] Only specific changes applied (not entire overlays)

## Code Review

- [ ] All platform changes in version control
- [ ] No ad-hoc kubectl edits without code updates
- [ ] CORS configuration includes required origins
- [ ] Proper semantic versioning used
- [ ] Documentation matches actual state
- [ ] Database backup procedures followed (if applicable)

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Database Management](./database-management.md) - Database backup and recovery procedures
- [Version Control Standards](./version-control-standards.md) - Git workflow requirements
