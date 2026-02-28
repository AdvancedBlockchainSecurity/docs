# Apogee Customer Support System

## Overview

| Component | Service | Purpose |
|-----------|---------|---------|
| Email Hosting | Google Workspace | support@0xapogee.com inbox |
| Ticketing | JIRA Service Management | Ticket management, SLAs, workflows |
| Marketing | TBD (Mailchimp/Brevo) | Campaigns, newsletters |

---

## Setup Checklist

### 1. Google Workspace Setup

- [ ] Go to [workspace.google.com](https://workspace.google.com)
- [ ] Start free trial (14 days) → $6/user/month after
- [ ] Enter domain: `0xapogee.com`
- [ ] Create first user: `support@0xapogee.com`
- [ ] Verify domain ownership (add TXT record to DNS)
- [ ] Add MX records to DNS:

```
Priority  Host    Points to
1         @       ASPMX.L.GOOGLE.COM
5         @       ALT1.ASPMX.L.GOOGLE.COM
5         @       ALT2.ASPMX.L.GOOGLE.COM
10        @       ALT3.ASPMX.L.GOOGLE.COM
10        @       ALT4.ASPMX.L.GOOGLE.COM
```

### 2. Connect Google Workspace to JSM

- [ ] In JSM: **Project Settings → Channels → Email**
- [ ] Click **Connect email account**
- [ ] Select **Google** integration
- [ ] Sign in with `support@0xapogee.com`
- [ ] Grant permissions for JSM to read/send emails
- [ ] Test: Send email to support@0xapogee.com → verify ticket created

### 3. Configure JSM Request Types

Create these request types in **Project Settings → Request Types**:

| Request Type | Description | Fields |
|--------------|-------------|--------|
| General Support | General inquiries | Summary, Description |
| Subscription/Billing | Payment, plan changes | Summary, Description, Customer ID, Plan Type |
| Technical Issue | Bugs, errors, technical help | Summary, Description, Severity, Steps to Reproduce |

### 4. Set Up Automation Rules

In **Project Settings → Automation**:

**Auto-acknowledge receipt:**
```
WHEN: Issue created
THEN: Send email to customer
      Subject: "We received your request [{{issue.key}}]"
      Body: "We've received your support request and will respond within 24 hours."
```

**Auto-assign subscription issues:**
```
WHEN: Issue created
IF: Request type = Subscription/Billing
THEN: Assign to [billing agent]
```

**Escalation if no response:**
```
WHEN: Issue updated (time condition: 4 hours since created)
IF: Status = Open AND Comments = 0
THEN: Send Slack/email notification to team
```

### 5. Add Support Agents

- [ ] **Project Settings → People → Add team members**
- [ ] Assign role: **Service Desk Team**
- [ ] Agents (up to 3 free): [Add names]

---

## Email Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                     INBOUND EMAIL                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Customer                                                  │
│      │                                                      │
│      ▼                                                      │
│   support@0xapogee.com (Google Workspace)                │
│      │                                                      │
│      ▼                                                      │
│   JSM creates ticket (SD-XXX)                               │
│      │                                                      │
│      ▼                                                      │
│   Auto-acknowledgment sent to customer                      │
│      │                                                      │
│      ▼                                                      │
│   Agent assigned (auto or manual)                           │
│      │                                                      │
│      ▼                                                      │
│   Agent responds in JSM                                     │
│      │                                                      │
│      ▼                                                      │
│   Customer receives email reply                             │
│      │                                                      │
│      ▼                                                      │
│   Customer replies → same ticket updated                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Linking Support Tickets to JIRA Software

When a support ticket needs dev work:

1. Open ticket in JSM
2. Click **Link** → **Create linked issue**
3. Select JIRA Software project
4. Choose issue type (Bug, Task, etc.)
5. Dev team sees linked issue in their backlog

**JQL to find support-related dev work:**
```
project = DEV AND issueFunction in linkedIssuesOf("project = SD")
```

---

## SLA Configuration

Recommended SLAs in **Project Settings → SLAs**:

| Metric | Target | Priority |
|--------|--------|----------|
| Time to first response | 4 hours | High |
| Time to first response | 8 hours | Medium |
| Time to first response | 24 hours | Low |
| Time to resolution | 1 day | High |
| Time to resolution | 3 days | Medium |
| Time to resolution | 5 days | Low |

---

## Canned Responses

Create in **Project Settings → Canned Responses**:

**Subscription - Plan Change:**
```
Hi {{reporter.displayName}},

Thanks for reaching out about changing your plan.

To update your subscription:
1. Log in to your account
2. Go to Settings → Subscription
3. Select your new plan

If you need help, let me know your Customer ID and desired plan, and I can process the change for you.

Best,
{{currentUser.displayName}}
```

**Technical - Need More Info:**
```
Hi {{reporter.displayName}},

Thanks for reporting this issue. To help investigate, could you provide:

- Steps to reproduce the problem
- Any error messages you see
- Browser/device you're using
- Screenshots if possible

Best,
{{currentUser.displayName}}
```

**Resolved - Issue Fixed:**
```
Hi {{reporter.displayName}},

This issue has been resolved. [Describe fix/solution]

Please let us know if you experience any further problems.

Best,
{{currentUser.displayName}}
```

---

## Marketing Email Setup (Future)

When ready to add marketing campaigns:

1. Choose provider: Mailchimp, Brevo, or Mailerlite
2. Add DNS records for email authentication:
   - SPF record (sender verification)
   - DKIM record (email signing)
   - DMARC record (policy)
3. Create email lists and segments
4. Design templates
5. Set up automation (welcome series, etc.)

**Recommended setup:**
- Support email: `support@0xapogee.com` (Google Workspace → JSM)
- Marketing email: `hello@0xapogee.com` or `news@0xapogee.com` (Marketing platform)

---

## Contacts

| Role | Name | Email |
|------|------|-------|
| Support Lead | TBD | support@0xapogee.com |
| Billing | TBD | |
| Technical | TBD | |
