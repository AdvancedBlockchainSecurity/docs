# Dashboard v0.46.4 - Frontend Security Hardening

**Date:** February 24, 2026
**Version:** 0.46.4
**Type:** Security (PATCH)
**PR:** #162

## Summary

Frontend security hardening for integration hub components and notification channel creation. Addresses 7 findings from the pre-GCP integration security audit.

## Changes

### URL Validation
- Fixed `isValidOAuthUrl()` to reject non-allowlisted hosts (was returning `true` for all HTTPS URLs)
- Avatar URLs (`external_avatar_url`) validated for `https://` protocol before rendering in `<img src>`
- JIRA site URLs validated for `https://` protocol before rendering in `<a href>`
- IDE marketplace URLs validated for `https://` protocol before rendering

### Error Handling
- Replaced raw `err?.response?.data?.detail` with `getErrorMessage(err)` across all integration tabs
- Changed `err: any` to `err: unknown` for type safety
- Affected: SourceControlTab, CICDTab, IssueTrackingTab

### Webhook Domain Validation
- Added per-provider webhook URL domain validation in CreateChannelModal
- Slack: must match `hooks.slack.com`
- Teams: must match `webhook.office.com` or `outlook.office.com`
- Discord: must match `discord.com` or `discordapp.com`

### API Request Fix
- IDE token update now sends data in request body instead of query parameters

## Files Modified

- `src/components/integrations/hub/CICDTab.tsx`
- `src/components/integrations/hub/SourceControlTab.tsx`
- `src/components/integrations/hub/IssueTrackingTab.tsx`
- `src/components/integrations/hub/OverviewTab.tsx`
- `src/components/integrations/hub/IDETab.tsx`
- `src/components/notification-channels/CreateChannelModal.tsx`
- `src/lib/api/ideIntegrations.ts`

### Version Files
- `package.json` (0.46.3 -> 0.46.4)
- `k8s/overlays/local/kustomization.yaml` (0.46.3 -> 0.46.4)

## Breaking Changes

None. All changes are backward-compatible security improvements.

## Deployment Notes

- No new environment variables or configuration required
- Standard build and deploy workflow
