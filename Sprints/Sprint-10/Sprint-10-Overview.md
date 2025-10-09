# Sprint 10: Advanced Enterprise Integration

**Duration**: Weeks 19-20 (2 weeks)
**Status**: Planning
**Technical Milestone**: Deep enterprise system integration

---

## Overview

Sprint 10 completes the enterprise feature set by integrating the platform deeply into enterprise workflows through ITSM, communication platforms, and comprehensive API capabilities. This sprint enables security teams to work seamlessly within their existing enterprise ecosystem, eliminating context switching and enabling automated security workflows.

### Key Objectives

1. **ITSM Integration**: Seamless integration with Jira and ServiceNow for ticket management
2. **Communication Platforms**: Deep integration with Teams, Slack, and Salesforce
3. **Enterprise API**: Comprehensive REST and GraphQL APIs for custom integrations
4. **Webhook System**: Real-time event streaming to external systems
5. **Dashboard Embedding**: Enable security dashboards in external portals
6. **SSO Propagation**: Seamless authentication across integrated systems

---

## Technical Milestone

**Deliverable**: Fully integrated enterprise ecosystem with automated workflow capabilities

**Success Criteria**:
- Findings automatically create tickets in Jira/ServiceNow
- Communication integrations provide interactive management
- Critical findings trigger escalation workflows
- APIs handle enterprise-scale integration loads
- SSO propagates seamlessly across integrated systems
- All acceptance criteria met

---

## Epic 1: ITSM & Ticketing Integration

### Epic Goal
Enable automated ticket creation and synchronization with enterprise ITSM platforms.

### Tasks

#### Task 10.1: Jira Integration

**Story**: As a security team using Jira, I want findings to automatically create Jira tickets so that we can track remediation in our existing workflow.

**Acceptance Criteria**:
- [ ] Jira OAuth 2.0 authentication implemented
- [ ] Automatic ticket creation from findings
- [ ] Bidirectional status synchronization
- [ ] Custom field mapping configuration
- [ ] Attachment synchronization (screenshots, reports)
- [ ] Comment synchronization between platforms
- [ ] Jira webhook handling for updates
- [ ] Tests for Jira integration

**Implementation Details**:
```python
# src/infrastructure/integrations/jira/jira_service.py
from jira import JIRA

class JiraIntegrationService:
    def __init__(self, organization: Organization):
        self.config = organization.jira_config
        self.client = JIRA(
            server=self.config.server_url,
            oauth={
                'access_token': self.config.access_token,
                'access_token_secret': self.config.access_token_secret,
                'consumer_key': self.config.consumer_key,
                'key_cert': self.config.private_key
            }
        )
        self.field_mapping = self.config.field_mapping

    async def create_ticket_from_finding(
        self,
        finding: Finding
    ) -> str:
        """Create Jira ticket from finding"""
        # Map finding fields to Jira fields
        issue_dict = {
            'project': {'key': self.config.project_key},
            'summary': finding.title,
            'description': self._format_description(finding),
            'issuetype': {'name': self.config.issue_type},
            'priority': {'name': self._map_priority(finding.severity)},
            self.field_mapping.get('severity'): finding.severity,
            self.field_mapping.get('finding_id'): str(finding.id),
            self.field_mapping.get('tool'): finding.tool,
        }

        # Add custom fields
        for custom_field, value in self._get_custom_fields(finding).items():
            issue_dict[custom_field] = value

        # Create issue
        issue = self.client.create_issue(fields=issue_dict)

        # Add attachments
        if finding.screenshot_url:
            screenshot = await self.download_screenshot(finding.screenshot_url)
            self.client.add_attachment(issue.key, screenshot, 'screenshot.png')

        # Store mapping
        await self.mapping_repo.create(FindingJiraMapping(
            finding_id=finding.id,
            jira_key=issue.key,
            jira_id=issue.id
        ))

        return issue.key

    async def sync_status_to_jira(
        self,
        finding: Finding,
        jira_key: str
    ):
        """Sync finding status to Jira"""
        issue = self.client.issue(jira_key)

        # Map finding status to Jira status
        jira_status = self._map_status(finding.status)

        # Transition issue
        transitions = self.client.transitions(issue)
        for transition in transitions:
            if transition['name'] == jira_status:
                self.client.transition_issue(
                    issue,
                    transition['id'],
                    comment=f"Status updated from Security Platform: {finding.status}"
                )
                break

    async def sync_status_from_jira(
        self,
        jira_key: str
    ):
        """Sync Jira status to finding"""
        mapping = await self.mapping_repo.get_by_jira_key(jira_key)
        issue = self.client.issue(jira_key)

        # Map Jira status to finding status
        finding_status = self._map_jira_status(issue.fields.status.name)

        # Update finding
        finding = await self.finding_repo.get(mapping.finding_id)
        if finding.status != finding_status:
            await self.workflow_service.transition_state(
                finding.id,
                finding_status,
                system_user_id,
                reason=f"Synced from Jira: {jira_key}"
            )

    async def sync_comments(
        self,
        finding: Finding,
        jira_key: str
    ):
        """Sync comments between platforms"""
        # Get latest comments from both sides
        finding_comments = await self.comment_repo.get_by_finding(finding.id)
        jira_comments = self.client.comments(jira_key)

        # Sync to Jira (comments not already synced)
        for comment in finding_comments:
            if not await self.is_synced_to_jira(comment.id, jira_key):
                self.client.add_comment(
                    jira_key,
                    f"[{comment.user.name}]: {comment.content}"
                )
                await self.mark_synced_to_jira(comment.id, jira_key)

        # Sync from Jira (comments not already synced)
        for jira_comment in jira_comments:
            if not await self.is_synced_from_jira(jira_comment.id):
                await self.comment_service.create_comment(
                    finding_id=finding.id,
                    user_id=self.get_jira_user_mapping(jira_comment.author),
                    content=f"[From Jira]: {jira_comment.body}"
                )
                await self.mark_synced_from_jira(jira_comment.id)

    def _format_description(self, finding: Finding) -> str:
        """Format finding as Jira description"""
        return f"""
*Security Finding Details*

*Severity:* {finding.severity.upper()}
*Tool:* {finding.tool}
*Contract:* {finding.contract.name}
*Location:* Line {finding.line_number}

*Description:*
{finding.description}

*Impact:*
{finding.impact}

*Recommendation:*
{finding.recommendation}

*View in Platform:* {self.get_finding_url(finding.id)}
        """

    def _map_priority(self, severity: str) -> str:
        """Map finding severity to Jira priority"""
        mapping = {
            'critical': 'Highest',
            'high': 'High',
            'medium': 'Medium',
            'low': 'Low',
            'informational': 'Lowest'
        }
        return mapping.get(severity, 'Medium')

    def _map_status(self, finding_status: str) -> str:
        """Map finding status to Jira status"""
        mapping = self.config.status_mapping or {
            'new': 'To Do',
            'triage': 'In Review',
            'in_progress': 'In Progress',
            'resolved': 'Done',
            'closed': 'Closed'
        }
        return mapping.get(finding_status, 'To Do')
```

**Jira Configuration Model**:
```python
# src/domain/models/jira_config.py
@dataclass
class JiraConfig:
    enabled: bool = False
    server_url: str = ""
    consumer_key: str = ""
    access_token: str = ""
    access_token_secret: str = ""
    private_key: str = ""
    project_key: str = ""
    issue_type: str = "Bug"
    field_mapping: Dict[str, str] = field(default_factory=dict)
    status_mapping: Dict[str, str] = field(default_factory=dict)
    auto_create_tickets: bool = True
    auto_sync_status: bool = True
    auto_sync_comments: bool = True
    create_on_severity: List[str] = field(default_factory=lambda: ['critical', 'high'])
```

**Webhook Handler**:
```python
# src/api/webhooks/jira_webhook.py
@app.post("/api/v1/webhooks/jira")
async def handle_jira_webhook(webhook_event: dict, background_tasks: BackgroundTasks):
    """Handle Jira webhook events"""
    event_type = webhook_event.get('webhookEvent')

    if event_type == 'jira:issue_updated':
        issue_key = webhook_event['issue']['key']
        background_tasks.add_task(
            jira_service.sync_status_from_jira,
            issue_key
        )
        background_tasks.add_task(
            jira_service.sync_comments_from_jira,
            issue_key
        )

    return {"status": "accepted"}
```

**Estimated Time**: 20 hours

**Dependencies**: None

---

#### Task 10.2: ServiceNow Integration

**Story**: As an enterprise IT team using ServiceNow, I want findings to create ServiceNow incidents so that we can manage them through our ITSM process.

**Acceptance Criteria**:
- [ ] ServiceNow REST API authentication
- [ ] Automatic incident creation from findings
- [ ] Incident status synchronization
- [ ] Assignment group mapping
- [ ] Attachment handling
- [ ] Work notes synchronization
- [ ] ServiceNow webhook integration
- [ ] Tests for ServiceNow integration

**ServiceNow Implementation**:
```python
# src/infrastructure/integrations/servicenow/servicenow_service.py
import requests

class ServiceNowIntegrationService:
    def __init__(self, organization: Organization):
        self.config = organization.servicenow_config
        self.base_url = f"https://{self.config.instance}.service-now.com"
        self.session = requests.Session()
        self.session.auth = (self.config.username, self.config.password)
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })

    async def create_incident_from_finding(
        self,
        finding: Finding
    ) -> str:
        """Create ServiceNow incident from finding"""
        payload = {
            'short_description': finding.title,
            'description': self._format_description(finding),
            'urgency': self._map_urgency(finding.severity),
            'impact': self._map_impact(finding.severity),
            'category': 'Security',
            'subcategory': 'Vulnerability',
            'assignment_group': self.config.assignment_group,
            'u_finding_id': str(finding.id),  # Custom field
            'u_severity': finding.severity,
            'u_tool': finding.tool,
            'u_contract': finding.contract.name
        }

        response = self.session.post(
            f"{self.base_url}/api/now/table/incident",
            json=payload
        )
        response.raise_for_status()

        incident = response.json()['result']
        sys_id = incident['sys_id']
        number = incident['number']

        # Store mapping
        await self.mapping_repo.create(FindingServiceNowMapping(
            finding_id=finding.id,
            incident_sys_id=sys_id,
            incident_number=number
        ))

        # Add attachments
        if finding.report_url:
            await self.add_attachment(sys_id, finding.report_url, 'report.pdf')

        return number

    async def sync_status_to_servicenow(
        self,
        finding: Finding,
        incident_sys_id: str
    ):
        """Sync finding status to ServiceNow"""
        state = self._map_state(finding.status)

        payload = {
            'state': state,
            'work_notes': f"Status updated from Security Platform: {finding.status}"
        }

        response = self.session.patch(
            f"{self.base_url}/api/now/table/incident/{incident_sys_id}",
            json=payload
        )
        response.raise_for_status()

    async def sync_status_from_servicenow(
        self,
        incident_number: str
    ):
        """Sync ServiceNow incident status to finding"""
        # Get incident
        response = self.session.get(
            f"{self.base_url}/api/now/table/incident",
            params={'sysparm_query': f'number={incident_number}'}
        )
        response.raise_for_status()

        incidents = response.json()['result']
        if not incidents:
            return

        incident = incidents[0]
        finding_id = incident.get('u_finding_id')
        if not finding_id:
            return

        # Map state
        finding_status = self._map_servicenow_state(incident['state'])

        # Update finding
        await self.workflow_service.transition_state(
            UUID(finding_id),
            finding_status,
            system_user_id,
            reason=f"Synced from ServiceNow: {incident_number}"
        )

    async def add_attachment(
        self,
        incident_sys_id: str,
        file_url: str,
        filename: str
    ):
        """Add attachment to ServiceNow incident"""
        # Download file
        file_content = await self.download_file(file_url)

        # Upload to ServiceNow
        headers = {'Content-Type': 'application/octet-stream'}
        response = self.session.post(
            f"{self.base_url}/api/now/attachment/file",
            params={
                'table_name': 'incident',
                'table_sys_id': incident_sys_id,
                'file_name': filename
            },
            headers=headers,
            data=file_content
        )
        response.raise_for_status()

    def _map_urgency(self, severity: str) -> str:
        """Map severity to ServiceNow urgency"""
        mapping = {
            'critical': '1',  # Critical
            'high': '2',      # High
            'medium': '3',    # Medium
            'low': '3'        # Medium
        }
        return mapping.get(severity, '3')

    def _map_impact(self, severity: str) -> str:
        """Map severity to ServiceNow impact"""
        mapping = {
            'critical': '1',  # High
            'high': '2',      # Medium
            'medium': '3',    # Low
            'low': '3'        # Low
        }
        return mapping.get(severity, '3')

    def _map_state(self, finding_status: str) -> str:
        """Map finding status to ServiceNow state"""
        mapping = {
            'new': '1',           # New
            'triage': '2',        # In Progress
            'in_progress': '2',   # In Progress
            'resolved': '6',      # Resolved
            'closed': '7'         # Closed
        }
        return mapping.get(finding_status, '1')
```

**Estimated Time**: 18 hours

**Dependencies**: None

---

#### Task 10.3: Ticket Lifecycle Management

**Story**: As a security analyst, I want ticket synchronization to be automatic and reliable so that I don't have to manually update multiple systems.

**Acceptance Criteria**:
- [ ] Automatic ticket creation based on rules
- [ ] Bidirectional status synchronization
- [ ] Conflict resolution for concurrent updates
- [ ] Sync failure retry with exponential backoff
- [ ] Manual sync trigger capability
- [ ] Sync status monitoring dashboard
- [ ] Sync audit logging
- [ ] Tests for all sync scenarios

**Ticket Sync Manager**:
```python
# src/domain/services/ticket_sync_manager.py
class TicketSyncManager:
    def __init__(self):
        self.providers = {
            'jira': JiraIntegrationService,
            'servicenow': ServiceNowIntegrationService
        }
        self.sync_queue = Queue()

    async def should_create_ticket(
        self,
        finding: Finding,
        organization: Organization
    ) -> bool:
        """Determine if ticket should be created"""
        config = organization.ticketing_config

        if not config.enabled:
            return False

        # Check severity threshold
        if finding.severity not in config.create_on_severity:
            return False

        # Check if already has ticket
        if await self.has_ticket(finding.id):
            return False

        # Check custom rules
        if config.custom_rules:
            return await self.evaluate_custom_rules(finding, config.custom_rules)

        return True

    async def create_ticket_for_finding(
        self,
        finding: Finding
    ):
        """Create ticket in configured system"""
        org = await self.org_repo.get(finding.organization_id)
        config = org.ticketing_config

        if not await self.should_create_ticket(finding, org):
            return

        provider = self.providers[config.provider](org)

        try:
            if config.provider == 'jira':
                ticket_key = await provider.create_ticket_from_finding(finding)
            elif config.provider == 'servicenow':
                ticket_key = await provider.create_incident_from_finding(finding)

            logger.info(f"Created {config.provider} ticket {ticket_key} for finding {finding.id}")

        except Exception as e:
            logger.error(f"Failed to create ticket for finding {finding.id}: {e}")
            await self.queue_retry(finding.id, 'create_ticket')

    async def sync_finding_update(
        self,
        finding: Finding,
        field_changed: str
    ):
        """Sync finding update to ticket"""
        mapping = await self.mapping_repo.get_by_finding(finding.id)
        if not mapping:
            return

        org = await self.org_repo.get(finding.organization_id)
        config = org.ticketing_config
        provider = self.providers[config.provider](org)

        try:
            if field_changed == 'status':
                await provider.sync_status_to_ticket(finding, mapping.ticket_key)
            elif field_changed == 'comments':
                await provider.sync_comments(finding, mapping.ticket_key)

            # Update last sync time
            mapping.last_synced_at = datetime.now()
            await self.mapping_repo.update(mapping)

        except Exception as e:
            logger.error(f"Failed to sync finding {finding.id} to ticket: {e}")
            await self.queue_retry(finding.id, f'sync_{field_changed}')

    async def handle_ticket_webhook(
        self,
        provider: str,
        event: dict
    ):
        """Handle incoming webhook from ticketing system"""
        if provider == 'jira':
            ticket_key = event['issue']['key']
            event_type = event['webhookEvent']
        elif provider == 'servicenow':
            ticket_key = event['incident']['number']
            event_type = event['action']

        # Find mapping
        mapping = await self.mapping_repo.get_by_ticket_key(ticket_key)
        if not mapping:
            logger.warning(f"Received webhook for unknown ticket: {ticket_key}")
            return

        # Sync based on event type
        if 'status' in event_type or 'state' in event_type:
            provider_service = self.providers[provider](
                await self.org_repo.get(mapping.organization_id)
            )
            await provider_service.sync_status_from_ticket(ticket_key)

    async def resolve_sync_conflict(
        self,
        finding: Finding,
        ticket_data: dict
    ):
        """Resolve conflict when both systems updated"""
        # Strategy: Last write wins with manual review for important conflicts
        finding_updated = finding.updated_at
        ticket_updated = datetime.fromisoformat(ticket_data['updated'])

        if ticket_updated > finding_updated:
            # Ticket is newer, sync to finding
            await self.sync_from_ticket(finding.id)
        else:
            # Finding is newer, sync to ticket
            await self.sync_to_ticket(finding.id)

        # Log conflict for review
        await self.audit_log.record(
            action='sync_conflict_resolved',
            finding_id=finding.id,
            details={
                'finding_updated': finding_updated.isoformat(),
                'ticket_updated': ticket_updated.isoformat(),
                'resolution': 'last_write_wins'
            }
        )
```

**Estimated Time**: 14 hours

**Dependencies**: Task 10.1, Task 10.2

---

#### Task 10.4: Custom Field Mapping

**Story**: As an admin, I want to configure custom field mappings so that our specific ITSM fields are populated correctly.

**Acceptance Criteria**:
- [ ] Field mapping configuration UI
- [ ] Support for custom Jira fields
- [ ] Support for ServiceNow custom fields
- [ ] Field value transformation rules
- [ ] Mapping validation
- [ ] Default mapping templates
- [ ] Import/export mapping configuration
- [ ] Tests for field mapping

**Field Mapping Configuration**:
```python
# src/domain/models/field_mapping.py
@dataclass
class FieldMapping:
    source_field: str
    target_field: str
    transformation: Optional[str] = None  # 'uppercase', 'lowercase', 'custom'
    transformation_function: Optional[str] = None  # Custom function name
    required: bool = False
    default_value: Optional[str] = None

@dataclass
class TicketingFieldMappingConfig:
    provider: str  # 'jira' or 'servicenow'
    mappings: List[FieldMapping]
    custom_transformations: Dict[str, str] = field(default_factory=dict)

class FieldMapper:
    def __init__(self, config: TicketingFieldMappingConfig):
        self.config = config
        self.transformations = self._load_transformations()

    def map_finding_to_ticket(self, finding: Finding) -> dict:
        """Map finding fields to ticket fields"""
        ticket_data = {}

        for mapping in self.config.mappings:
            source_value = getattr(finding, mapping.source_field, None)

            if source_value is None and mapping.required:
                source_value = mapping.default_value

            if mapping.transformation:
                source_value = self._apply_transformation(
                    source_value,
                    mapping.transformation,
                    mapping.transformation_function
                )

            ticket_data[mapping.target_field] = source_value

        return ticket_data

    def _apply_transformation(
        self,
        value: Any,
        transformation_type: str,
        custom_function: Optional[str] = None
    ) -> Any:
        """Apply transformation to field value"""
        if transformation_type == 'uppercase':
            return str(value).upper()
        elif transformation_type == 'lowercase':
            return str(value).lower()
        elif transformation_type == 'custom' and custom_function:
            func = self.transformations.get(custom_function)
            if func:
                return func(value)

        return value

    def _load_transformations(self) -> Dict[str, Callable]:
        """Load custom transformation functions"""
        transformations = {}
        for name, code in self.config.custom_transformations.items():
            # Safely execute custom transformation
            namespace = {}
            exec(code, namespace)
            transformations[name] = namespace.get('transform')
        return transformations
```

**UI Configuration Component**:
```typescript
// src/components/admin/FieldMappingConfig.tsx
interface FieldMappingConfigProps {
  provider: 'jira' | 'servicenow';
  currentMappings: FieldMapping[];
  onSave: (mappings: FieldMapping[]) => Promise<void>;
}

const FieldMappingConfig: React.FC<FieldMappingConfigProps> = ({
  provider,
  currentMappings,
  onSave
}) => {
  const [mappings, setMappings] = useState(currentMappings);

  const availableSourceFields = [
    'title', 'description', 'severity', 'status', 'tool',
    'contract_name', 'line_number', 'impact', 'recommendation'
  ];

  const availableTargetFields = provider === 'jira' ? [
    'summary', 'description', 'priority', 'status', 'labels',
    'customfield_10001', 'customfield_10002'
  ] : [
    'short_description', 'description', 'urgency', 'impact', 'category',
    'u_custom_field_1', 'u_custom_field_2'
  ];

  const addMapping = () => {
    setMappings([...mappings, {
      source_field: '',
      target_field: '',
      transformation: null,
      required: false
    }]);
  };

  return (
    <div className="field-mapping-config">
      <h3>Field Mapping Configuration</h3>

      {mappings.map((mapping, index) => (
        <div key={index} className="mapping-row">
          <Select
            label="Source Field"
            options={availableSourceFields}
            value={mapping.source_field}
            onChange={(value) => updateMapping(index, 'source_field', value)}
          />

          <Select
            label="Target Field"
            options={availableTargetFields}
            value={mapping.target_field}
            onChange={(value) => updateMapping(index, 'target_field', value)}
          />

          <Select
            label="Transformation"
            options={['none', 'uppercase', 'lowercase', 'custom']}
            value={mapping.transformation || 'none'}
            onChange={(value) => updateMapping(index, 'transformation', value)}
          />

          <Checkbox
            label="Required"
            checked={mapping.required}
            onChange={(checked) => updateMapping(index, 'required', checked)}
          />

          <Button onClick={() => removeMapping(index)}>Remove</Button>
        </div>
      ))}

      <Button onClick={addMapping}>Add Mapping</Button>
      <Button onClick={() => onSave(mappings)} variant="primary">
        Save Configuration
      </Button>
    </div>
  );
};
```

**Estimated Time**: 12 hours

**Dependencies**: Task 10.1, Task 10.2

---

## Epic 2: Communication Platform Integration

### Epic Goal
Enable deep integration with enterprise communication platforms.

### Tasks

#### Task 10.5: Advanced Microsoft Teams Integration

**Story**: As a team using Microsoft Teams, I want rich interactive cards and bot capabilities so that we can manage findings without leaving Teams.

**Acceptance Criteria**:
- [ ] Teams bot registration and configuration
- [ ] Adaptive card templates for all finding events
- [ ] Interactive actions in cards (assign, comment, change status)
- [ ] Teams channel selection for notifications
- [ ] Personal chat notifications
- [ ] Bot commands for querying findings
- [ ] Activity feed integration
- [ ] Tests for Teams integration

**Microsoft Teams Bot**:
```python
# src/infrastructure/integrations/teams/teams_bot.py
from botbuilder.core import ActivityHandler, TurnContext
from botbuilder.schema import Activity, ActivityTypes, CardAction, HeroCard

class SecurityPlatformBot(ActivityHandler):
    async def on_message_activity(self, turn_context: TurnContext):
        """Handle incoming messages"""
        text = turn_context.activity.text.lower().strip()

        if text.startswith('/finding'):
            await self.handle_finding_command(turn_context, text)
        elif text.startswith('/help'):
            await self.send_help_card(turn_context)
        else:
            await turn_context.send_activity(
                "I didn't understand that. Type /help to see available commands."
            )

    async def handle_finding_command(self, turn_context: TurnContext, text: str):
        """Handle /finding commands"""
        parts = text.split()
        if len(parts) < 2:
            await turn_context.send_activity("Usage: /finding <search|status|assign> ...")
            return

        command = parts[1]

        if command == 'search':
            query = ' '.join(parts[2:])
            findings = await self.finding_service.search(query, limit=5)
            await self.send_findings_card(turn_context, findings)

        elif command == 'status':
            finding_id = parts[2] if len(parts) > 2 else None
            if not finding_id:
                await turn_context.send_activity("Usage: /finding status <finding_id>")
                return

            finding = await self.finding_service.get(UUID(finding_id))
            await self.send_finding_detail_card(turn_context, finding)

    async def on_teams_card_action_invoke(self, turn_context: TurnContext):
        """Handle card action invocations"""
        value = turn_context.activity.value
        action = value.get('action')

        if action == 'assign_finding':
            finding_id = UUID(value['finding_id'])
            user_id = UUID(value['user_id'])
            await self.finding_service.assign(finding_id, user_id)
            await turn_context.send_activity(f"✓ Finding assigned successfully")

        elif action == 'change_status':
            finding_id = UUID(value['finding_id'])
            new_status = value['status']
            await self.workflow_service.transition_state(finding_id, new_status)
            await turn_context.send_activity(f"✓ Status changed to {new_status}")

        elif action == 'add_comment':
            # Show comment input dialog
            await self.show_comment_dialog(turn_context, value['finding_id'])

class TeamsNotificationService:
    async def send_finding_notification(
        self,
        finding: Finding,
        channel_id: str
    ):
        """Send finding notification to Teams channel"""
        card = self._create_finding_card(finding)

        message = Activity(
            type=ActivityTypes.message,
            attachments=[card]
        )

        await self.teams_client.conversations.send_to_conversation(
            channel_id,
            message
        )

    def _create_finding_card(self, finding: Finding) -> dict:
        """Create adaptive card for finding"""
        severity_color = {
            'critical': 'attention',
            'high': 'warning',
            'medium': 'accent',
            'low': 'good'
        }.get(finding.severity, 'default')

        return {
            "contentType": "application/vnd.microsoft.card.adaptive",
            "content": {
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.4",
                "body": [
                    {
                        "type": "Container",
                        "style": severity_color,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": f"🔴 {finding.severity.upper()} Finding",
                                "weight": "Bolder",
                                "size": "Large"
                            }
                        ]
                    },
                    {
                        "type": "TextBlock",
                        "text": finding.title,
                        "weight": "Bolder",
                        "size": "Medium",
                        "wrap": True
                    },
                    {
                        "type": "FactSet",
                        "facts": [
                            {"title": "Contract:", "value": finding.contract.name},
                            {"title": "Tool:", "value": finding.tool},
                            {"title": "Status:", "value": finding.status},
                            {"title": "Assigned:", "value": finding.assignee or "Unassigned"}
                        ]
                    },
                    {
                        "type": "TextBlock",
                        "text": finding.description[:200] + "..." if len(finding.description) > 200 else finding.description,
                        "wrap": True
                    }
                ],
                "actions": [
                    {
                        "type": "Action.OpenUrl",
                        "title": "View Details",
                        "url": self.get_finding_url(finding.id)
                    },
                    {
                        "type": "Action.Submit",
                        "title": "Assign to Me",
                        "data": {
                            "action": "assign_finding",
                            "finding_id": str(finding.id),
                            "user_id": "${user_id}"
                        }
                    },
                    {
                        "type": "Action.ShowCard",
                        "title": "Change Status",
                        "card": {
                            "type": "AdaptiveCard",
                            "body": [
                                {
                                    "type": "Input.ChoiceSet",
                                    "id": "status",
                                    "choices": [
                                        {"title": "In Progress", "value": "in_progress"},
                                        {"title": "Resolved", "value": "resolved"},
                                        {"title": "Won't Fix", "value": "wont_fix"}
                                    ]
                                }
                            ],
                            "actions": [
                                {
                                    "type": "Action.Submit",
                                    "title": "Update",
                                    "data": {
                                        "action": "change_status",
                                        "finding_id": str(finding.id)
                                    }
                                }
                            ]
                        }
                    }
                ]
            }
        }
```

**Estimated Time**: 20 hours

**Dependencies**: None

---

#### Task 10.6: Salesforce Integration

**Story**: As a customer success team using Salesforce, I want security findings linked to customer accounts so that we can track security posture.

**Acceptance Criteria**:
- [ ] Salesforce OAuth integration
- [ ] Custom object creation for findings
- [ ] Account linkage configuration
- [ ] Finding sync to Salesforce
- [ ] Salesforce dashboard components
- [ ] Security score calculation
- [ ] Apex trigger for notifications
- [ ] Tests for Salesforce integration

**Salesforce Integration**:
```python
# src/infrastructure/integrations/salesforce/salesforce_service.py
from simple_salesforce import Salesforce

class SalesforceIntegrationService:
    def __init__(self, organization: Organization):
        self.config = organization.salesforce_config
        self.client = Salesforce(
            username=self.config.username,
            password=self.config.password,
            security_token=self.config.security_token,
            domain=self.config.domain
        )

    async def create_finding_record(
        self,
        finding: Finding,
        account_id: str
    ) -> str:
        """Create finding record in Salesforce"""
        finding_data = {
            'Name': finding.title,
            'Account__c': account_id,
            'Severity__c': finding.severity,
            'Status__c': finding.status,
            'Tool__c': finding.tool,
            'Contract__c': finding.contract.name,
            'Description__c': finding.description,
            'Impact__c': finding.impact,
            'Recommendation__c': finding.recommendation,
            'External_ID__c': str(finding.id),
            'Finding_URL__c': self.get_finding_url(finding.id)
        }

        result = self.client.Security_Finding__c.create(finding_data)
        return result['id']

    async def update_account_security_score(
        self,
        account_id: str
    ):
        """Update security score for account"""
        # Get all findings for account
        findings = self.client.query(
            f"SELECT Severity__c FROM Security_Finding__c "
            f"WHERE Account__c = '{account_id}' AND Status__c != 'Closed'"
        )

        # Calculate score
        score = self._calculate_security_score(findings['records'])

        # Update account
        self.client.Account.update(account_id, {
            'Security_Score__c': score,
            'Last_Security_Update__c': datetime.now().isoformat()
        })

    def _calculate_security_score(self, findings: List[dict]) -> int:
        """Calculate security score (0-100)"""
        base_score = 100

        # Deduct points based on severity
        severity_penalties = {
            'critical': 20,
            'high': 10,
            'medium': 5,
            'low': 2
        }

        for finding in findings:
            severity = finding['Severity__c'].lower()
            penalty = severity_penalties.get(severity, 0)
            base_score -= penalty

        return max(0, base_score)

    async def create_dashboard_component(
        self,
        account_id: str
    ) -> str:
        """Create Salesforce dashboard component for findings"""
        # Create chart showing finding distribution
        chart_config = {
            'chartType': 'Donut',
            'title': 'Security Findings by Severity',
            'groupingColumn': 'Severity__c',
            'aggregateColumn': 'Id',
            'aggregateType': 'Count'
        }

        # This would integrate with Salesforce Analytics API
        # Simplified for example
        return "dashboard_component_id"
```

**Apex Trigger** (for Salesforce admin to install):
```apex
// Apex trigger for finding notifications
trigger SecurityFindingNotification on Security_Finding__c (after insert, after update) {
    for (Security_Finding__c finding : Trigger.new) {
        if (finding.Severity__c == 'Critical') {
            // Send Chatter notification
            FeedItem post = new FeedItem();
            post.ParentId = finding.Account__c;
            post.Body = '🔴 Critical security finding: ' + finding.Name +
                       '\n\nView details: ' + finding.Finding_URL__c;
            insert post;

            // Send email to account owner
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(finding.Account__r.OwnerId);
            email.setSubject('Critical Security Finding: ' + finding.Name);
            email.setHtmlBody('A critical security finding has been identified...');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
}
```

**Estimated Time**: 18 hours

**Dependencies**: None

---

#### Task 10.7: Advanced Slack Integration

**Story**: As a team using Slack, I want slash commands and interactive components so that we can manage findings from Slack.

**Acceptance Criteria**:
- [ ] Slack slash commands implemented
- [ ] Interactive message components
- [ ] Modal dialogs for complex actions
- [ ] Shortcuts for quick actions
- [ ] Home tab with finding summary
- [ ] Workflow builder integration
- [ ] Custom emoji reactions for status
- [ ] Tests for Slack integration

**Advanced Slack Features**:
```python
# src/infrastructure/integrations/slack/slack_advanced.py
from slack_bolt import App
from slack_bolt.adapter.fastapi import SlackRequestHandler

class AdvancedSlackIntegration:
    def __init__(self):
        self.app = App(
            token=os.environ.get("SLACK_BOT_TOKEN"),
            signing_secret=os.environ.get("SLACK_SIGNING_SECRET")
        )
        self._register_handlers()

    def _register_handlers(self):
        """Register all Slack event handlers"""
        self.app.command("/finding")(self.handle_finding_command)
        self.app.action("assign_finding")(self.handle_assign_action)
        self.app.action("change_status")(self.handle_status_action)
        self.app.shortcut("create_finding")(self.handle_create_shortcut)
        self.app.event("app_home_opened")(self.update_home_tab)

    async def handle_finding_command(self, ack, command, client):
        """Handle /finding slash command"""
        await ack()

        text = command['text'].strip()
        parts = text.split()

        if not parts:
            await client.chat_postMessage(
                channel=command['channel_id'],
                text="Usage: `/finding search <query>` or `/finding list`"
            )
            return

        subcommand = parts[0]

        if subcommand == 'search':
            query = ' '.join(parts[1:])
            findings = await self.finding_service.search(query, limit=5)
            await self.send_findings_list(client, command['channel_id'], findings)

        elif subcommand == 'list':
            findings = await self.finding_service.get_user_findings(
                command['user_id'],
                limit=10
            )
            await self.send_findings_list(client, command['channel_id'], findings)

        elif subcommand == 'create':
            # Open modal for creating finding
            await client.views_open(
                trigger_id=command['trigger_id'],
                view=self.create_finding_modal()
            )

    async def handle_assign_action(self, ack, action, client):
        """Handle finding assignment action"""
        await ack()

        finding_id = UUID(action['value'])
        user_id = action['user']['id']

        # Map Slack user to platform user
        platform_user = await self.user_mapping_service.get_platform_user(user_id)

        # Assign finding
        await self.finding_service.assign(finding_id, platform_user.id)

        # Update message
        await client.chat_update(
            channel=action['channel']['id'],
            ts=action['message']['ts'],
            blocks=self.create_finding_blocks(
                await self.finding_service.get(finding_id)
            )
        )

    async def handle_create_shortcut(self, ack, shortcut, client):
        """Handle create finding shortcut"""
        await ack()

        await client.views_open(
            trigger_id=shortcut['trigger_id'],
            view=self.create_finding_modal()
        )

    async def update_home_tab(self, event, client):
        """Update user's home tab"""
        user_id = event['user']
        platform_user = await self.user_mapping_service.get_platform_user(user_id)

        # Get user's findings
        findings = await self.finding_service.get_user_findings(
            platform_user.id,
            limit=10
        )

        # Create home tab view
        await client.views_publish(
            user_id=user_id,
            view={
                "type": "home",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": "Your Security Findings"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"You have *{len(findings)}* assigned findings"
                        }
                    },
                    *[self.create_finding_block(f) for f in findings]
                ]
            }
        )

    def create_finding_modal(self) -> dict:
        """Create modal for finding creation"""
        return {
            "type": "modal",
            "callback_id": "create_finding",
            "title": {"type": "plain_text", "text": "Create Finding"},
            "submit": {"type": "plain_text", "text": "Create"},
            "blocks": [
                {
                    "type": "input",
                    "block_id": "title",
                    "label": {"type": "plain_text", "text": "Title"},
                    "element": {
                        "type": "plain_text_input",
                        "action_id": "title_input"
                    }
                },
                {
                    "type": "input",
                    "block_id": "severity",
                    "label": {"type": "plain_text", "text": "Severity"},
                    "element": {
                        "type": "static_select",
                        "action_id": "severity_select",
                        "options": [
                            {"text": {"type": "plain_text", "text": "Critical"}, "value": "critical"},
                            {"text": {"type": "plain_text", "text": "High"}, "value": "high"},
                            {"text": {"type": "plain_text", "text": "Medium"}, "value": "medium"},
                            {"text": {"type": "plain_text", "text": "Low"}, "value": "low"}
                        ]
                    }
                },
                {
                    "type": "input",
                    "block_id": "description",
                    "label": {"type": "plain_text", "text": "Description"},
                    "element": {
                        "type": "plain_text_input",
                        "action_id": "description_input",
                        "multiline": True
                    }
                }
            ]
        }

# FastAPI integration
slack_handler = SlackRequestHandler(slack_integration.app)

@app.post("/api/v1/slack/events")
async def slack_events(req: Request):
    """Handle Slack events"""
    return await slack_handler.handle(req)
```

**Estimated Time**: 16 hours

**Dependencies**: None (enhances existing Slack integration from Sprint 8)

---

#### Task 10.8: Dashboard Embedding

**Story**: As a customer, I want to embed security dashboards in our internal portal so that stakeholders can view security status without logging into another system.

**Acceptance Criteria**:
- [ ] Embeddable dashboard iframe generation
- [ ] JWT-based secure embedding
- [ ] Customizable dashboard themes
- [ ] Whitelabel options (custom logo, colors)
- [ ] Dashboard permission controls
- [ ] Auto-refresh capability
- [ ] Responsive iframe sizing
- [ ] Tests for embedding security

**Dashboard Embedding**:
```python
# src/application/services/dashboard_embedding_service.py
class DashboardEmbeddingService:
    async def generate_embed_token(
        self,
        user: User,
        dashboard_type: str,
        filters: Optional[Dict] = None,
        expires_in: int = 3600
    ) -> str:
        """Generate secure embedding token"""
        payload = {
            'user_id': str(user.id),
            'organization_id': str(user.organization_id),
            'dashboard_type': dashboard_type,
            'filters': filters or {},
            'exp': datetime.now() + timedelta(seconds=expires_in),
            'iat': datetime.now()
        }

        token = jwt.encode(
            payload,
            self.secret_key,
            algorithm='HS256'
        )

        return token

    async def get_embed_url(
        self,
        user: User,
        dashboard_type: str,
        theme: Optional[str] = None,
        filters: Optional[Dict] = None
    ) -> str:
        """Get embeddable dashboard URL"""
        token = await self.generate_embed_token(user, dashboard_type, filters)

        params = {
            'token': token,
            'theme': theme or 'light',
            'refresh': 'auto'
        }

        return f"{self.base_url}/embed/dashboard/{dashboard_type}?{urlencode(params)}"

    async def validate_embed_token(self, token: str) -> dict:
        """Validate embedding token"""
        try:
            payload = jwt.decode(
                token,
                self.secret_key,
                algorithms=['HS256']
            )
            return payload
        except jwt.ExpiredSignatureError:
            raise EmbedTokenExpiredError("Embedding token has expired")
        except jwt.InvalidTokenError:
            raise InvalidEmbedTokenError("Invalid embedding token")

# API endpoints
@app.get("/api/v1/embed/generate-token")
async def generate_embed_token(
    dashboard_type: str,
    theme: str = 'light',
    current_user: User = Depends(get_current_user)
):
    """Generate dashboard embedding token"""
    url = await embedding_service.get_embed_url(
        current_user,
        dashboard_type,
        theme=theme
    )

    return {
        'embed_url': url,
        'expires_in': 3600
    }

@app.get("/embed/dashboard/{dashboard_type}")
async def embedded_dashboard(
    dashboard_type: str,
    token: str,
    theme: str = 'light'
):
    """Serve embedded dashboard"""
    # Validate token
    payload = await embedding_service.validate_embed_token(token)

    # Return HTML with iframe-friendly dashboard
    return HTMLResponse(content=f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {{ margin: 0; padding: 0; overflow: hidden; }}
            .dashboard-container {{ width: 100vw; height: 100vh; }}
        </style>
    </head>
    <body>
        <div id="dashboard" class="dashboard-container"></div>
        <script src="/static/embed/dashboard.js"></script>
        <script>
            initializeDashboard({{
                type: '{dashboard_type}',
                theme: '{theme}',
                organizationId: '{payload["organization_id"]}',
                filters: {json.dumps(payload.get("filters", {}))}
            }});
        </script>
    </body>
    </html>
    """)
```

**Frontend Embedding Component**:
```typescript
// src/components/embed/DashboardEmbed.tsx
interface DashboardEmbedProps {
  dashboardType: string;
  theme?: 'light' | 'dark';
  height?: string;
  onLoad?: () => void;
}

export const DashboardEmbed: React.FC<DashboardEmbedProps> = ({
  dashboardType,
  theme = 'light',
  height = '600px',
  onLoad
}) => {
  const [embedUrl, setEmbedUrl] = useState<string>('');

  useEffect(() => {
    // Generate embed token
    api.get('/embed/generate-token', {
      params: { dashboard_type: dashboardType, theme }
    }).then(response => {
      setEmbedUrl(response.data.embed_url);
    });
  }, [dashboardType, theme]);

  return (
    <iframe
      src={embedUrl}
      width="100%"
      height={height}
      frameBorder="0"
      onLoad={onLoad}
      sandbox="allow-scripts allow-same-origin"
      title={`${dashboardType} Dashboard`}
    />
  );
};
```

**Usage Example**:
```html
<!-- Customer's internal portal -->
<html>
<head>
  <title>Security Dashboard</title>
</head>
<body>
  <!-- Embed security dashboard -->
  <iframe
    src="https://platform.com/embed/dashboard/overview?token=eyJ..."
    width="100%"
    height="800px"
    frameborder="0"
    sandbox="allow-scripts allow-same-origin"
  ></iframe>
</body>
</html>
```

**Estimated Time**: 14 hours

**Dependencies**: None

---

## Epic 3: Enterprise API & Automation

### Epic Goal
Provide comprehensive APIs for enterprise integration and automation.

### Tasks

#### Task 10.9: Comprehensive REST API

**Story**: As an integration developer, I need a complete REST API so that I can build custom integrations with our internal systems.

**Acceptance Criteria**:
- [ ] Complete REST API for all resources
- [ ] OpenAPI 3.0 specification generated
- [ ] API versioning strategy implemented
- [ ] Pagination for list endpoints
- [ ] Filtering and sorting support
- [ ] Bulk operation endpoints
- [ ] Comprehensive error responses
- [ ] API client libraries (Python, Node.js)
- [ ] Tests for all API endpoints

**API Design**:
```python
# src/api/v1/findings_api.py
@app.get("/api/v1/findings", response_model=PaginatedResponse[Finding])
async def list_findings(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    severity: Optional[List[str]] = Query(None),
    status: Optional[List[str]] = Query(None),
    tool: Optional[List[str]] = Query(None),
    sort_by: str = Query('created_at'),
    sort_order: str = Query('desc', regex='^(asc|desc)$'),
    search: Optional[str] = None,
    current_user: User = Depends(get_current_user)
):
    """List findings with filtering and pagination"""
    filters = FindingFilters(
        organization_id=current_user.organization_id,
        severity=severity,
        status=status,
        tool=tool,
        search=search
    )

    findings, total = await finding_service.list_findings(
        filters=filters,
        page=page,
        per_page=per_page,
        sort_by=sort_by,
        sort_order=sort_order
    )

    return PaginatedResponse(
        items=findings,
        total=total,
        page=page,
        per_page=per_page,
        pages=ceil(total / per_page)
    )

@app.post("/api/v1/findings/bulk-update")
async def bulk_update_findings(
    updates: BulkUpdateRequest,
    current_user: User = Depends(get_current_user)
):
    """Bulk update findings"""
    results = await finding_service.bulk_update(
        finding_ids=updates.finding_ids,
        updates=updates.updates,
        user_id=current_user.id
    )

    return {
        'success': sum(1 for r in results if r.success),
        'failed': sum(1 for r in results if not r.success),
        'results': results
    }

# OpenAPI schema generation
@app.get("/api/v1/openapi.json")
async def get_openapi_schema():
    """Get OpenAPI 3.0 specification"""
    return app.openapi()
```

**API Client Libraries**:
```python
# sdk/python/security_platform/client.py
class SecurityPlatformClient:
    def __init__(self, api_key: str, base_url: str = "https://api.platform.com"):
        self.api_key = api_key
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        })

    def list_findings(
        self,
        page: int = 1,
        per_page: int = 20,
        **filters
    ) -> PaginatedResponse:
        """List findings with filters"""
        response = self.session.get(
            f"{self.base_url}/api/v1/findings",
            params={'page': page, 'per_page': per_page, **filters}
        )
        response.raise_for_status()
        return PaginatedResponse(**response.json())

    def get_finding(self, finding_id: str) -> Finding:
        """Get finding by ID"""
        response = self.session.get(
            f"{self.base_url}/api/v1/findings/{finding_id}"
        )
        response.raise_for_status()
        return Finding(**response.json())

    def update_finding(
        self,
        finding_id: str,
        **updates
    ) -> Finding:
        """Update finding"""
        response = self.session.patch(
            f"{self.base_url}/api/v1/findings/{finding_id}",
            json=updates
        )
        response.raise_for_status()
        return Finding(**response.json())

# Usage
client = SecurityPlatformClient(api_key="sk_...")
findings = client.list_findings(severity=['critical', 'high'], status='open')
for finding in findings.items:
    print(f"{finding.title} - {finding.severity}")
```

**Estimated Time**: 16 hours

**Dependencies**: None

---

#### Task 10.10: Webhook System

**Story**: As an integration developer, I need webhooks so that our systems can react to platform events in real-time.

**Acceptance Criteria**:
- [ ] Webhook registration API
- [ ] Event subscription management
- [ ] Webhook delivery with retry logic
- [ ] Delivery status tracking
- [ ] Signature verification for security
- [ ] Webhook testing capability
- [ ] Dead letter queue for failed webhooks
- [ ] Tests for webhook delivery

**Webhook System**:
```python
# src/infrastructure/webhooks/webhook_manager.py
import hmac
import hashlib

class WebhookManager:
    async def register_webhook(
        self,
        organization_id: UUID,
        url: str,
        events: List[str],
        secret: Optional[str] = None
    ) -> Webhook:
        """Register webhook"""
        webhook = Webhook(
            organization_id=organization_id,
            url=url,
            events=events,
            secret=secret or secrets.token_hex(32),
            active=True
        )

        await self.webhook_repo.create(webhook)
        return webhook

    async def deliver_event(
        self,
        event_type: str,
        payload: dict,
        organization_id: UUID
    ):
        """Deliver event to registered webhooks"""
        webhooks = await self.webhook_repo.find_by_event(
            organization_id,
            event_type
        )

        for webhook in webhooks:
            if not webhook.active:
                continue

            # Queue delivery
            await self.delivery_queue.enqueue(
                webhook_id=webhook.id,
                event_type=event_type,
                payload=payload,
                attempt=1
            )

    async def process_webhook_delivery(
        self,
        webhook_id: UUID,
        event_type: str,
        payload: dict,
        attempt: int
    ):
        """Process webhook delivery"""
        webhook = await self.webhook_repo.get(webhook_id)

        # Create signature
        signature = self._create_signature(payload, webhook.secret)

        # Deliver webhook
        try:
            response = await self.http_client.post(
                webhook.url,
                json={
                    'event': event_type,
                    'data': payload,
                    'timestamp': datetime.now().isoformat()
                },
                headers={
                    'X-Webhook-Signature': signature,
                    'X-Webhook-Event': event_type,
                    'User-Agent': 'SecurityPlatform-Webhook/1.0'
                },
                timeout=10
            )

            if response.status_code < 300:
                # Success
                await self.webhook_delivery_repo.create(WebhookDelivery(
                    webhook_id=webhook_id,
                    event_type=event_type,
                    status='delivered',
                    response_code=response.status_code,
                    delivered_at=datetime.now()
                ))
            else:
                raise WebhookDeliveryError(f"HTTP {response.status_code}")

        except Exception as e:
            logger.error(f"Webhook delivery failed: {e}")

            # Retry with exponential backoff
            if attempt < 5:
                delay = 2 ** attempt * 60  # 2min, 4min, 8min, 16min, 32min
                await self.delivery_queue.enqueue(
                    webhook_id=webhook_id,
                    event_type=event_type,
                    payload=payload,
                    attempt=attempt + 1,
                    delay=delay
                )
            else:
                # Move to dead letter queue
                await self.dlq.enqueue({
                    'webhook_id': webhook_id,
                    'event_type': event_type,
                    'payload': payload,
                    'error': str(e)
                })

                # Record failure
                await self.webhook_delivery_repo.create(WebhookDelivery(
                    webhook_id=webhook_id,
                    event_type=event_type,
                    status='failed',
                    error=str(e),
                    attempts=attempt
                ))

    def _create_signature(self, payload: dict, secret: str) -> str:
        """Create HMAC signature for payload"""
        payload_bytes = json.dumps(payload, sort_keys=True).encode()
        signature = hmac.new(
            secret.encode(),
            payload_bytes,
            hashlib.sha256
        ).hexdigest()
        return f"sha256={signature}"

# Event publisher
class EventPublisher:
    async def publish(
        self,
        event_type: str,
        entity: Any,
        organization_id: UUID
    ):
        """Publish event to webhooks"""
        payload = self._serialize_entity(entity)

        await self.webhook_manager.deliver_event(
            event_type=event_type,
            payload=payload,
            organization_id=organization_id
        )

# Usage
@app.post("/api/v1/findings")
async def create_finding(finding: FindingCreate):
    """Create finding and trigger webhook"""
    finding = await finding_service.create(finding)

    # Publish event
    await event_publisher.publish(
        event_type='finding.created',
        entity=finding,
        organization_id=finding.organization_id
    )

    return finding

# Webhook verification (for client)
def verify_webhook_signature(payload: bytes, signature: str, secret: str) -> bool:
    """Verify webhook signature"""
    expected_signature = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(
        f"sha256={expected_signature}",
        signature
    )
```

**Webhook Events**:
- `finding.created`
- `finding.updated`
- `finding.status_changed`
- `finding.assigned`
- `contract.analyzed`
- `analysis.completed`
- `user.invited`
- `ticket.created`

**Estimated Time**: 16 hours

**Dependencies**: None

---

#### Task 10.11: GraphQL API

**Story**: As a frontend developer, I want a GraphQL API so that I can fetch exactly the data I need efficiently.

**Acceptance Criteria**:
- [ ] GraphQL schema defined for all resources
- [ ] Query support with filtering
- [ ] Mutation support for updates
- [ ] Subscription support for real-time updates
- [ ] DataLoader for N+1 query prevention
- [ ] Query complexity analysis
- [ ] GraphQL playground enabled
- [ ] Tests for GraphQL operations

**GraphQL Implementation**:
```python
# src/api/graphql/schema.py
import strawberry
from strawberry.fastapi import GraphQLRouter

@strawberry.type
class Finding:
    id: strawberry.ID
    title: str
    description: str
    severity: str
    status: str
    tool: str
    contract: 'Contract'
    assignees: List['User']
    comments: List['Comment']

@strawberry.type
class Contract:
    id: strawberry.ID
    name: str
    language: str
    findings: List[Finding]

@strawberry.type
class User:
    id: strawberry.ID
    email: str
    name: str
    assigned_findings: List[Finding]

@strawberry.type
class Query:
    @strawberry.field
    async def finding(self, id: strawberry.ID) -> Optional[Finding]:
        """Get finding by ID"""
        return await finding_service.get(UUID(id))

    @strawberry.field
    async def findings(
        self,
        page: int = 1,
        per_page: int = 20,
        severity: Optional[List[str]] = None,
        status: Optional[List[str]] = None
    ) -> List[Finding]:
        """List findings with filters"""
        filters = FindingFilters(severity=severity, status=status)
        findings, _ = await finding_service.list_findings(
            filters=filters,
            page=page,
            per_page=per_page
        )
        return findings

@strawberry.type
class Mutation:
    @strawberry.mutation
    async def update_finding(
        self,
        id: strawberry.ID,
        status: Optional[str] = None,
        assigned_to: Optional[strawberry.ID] = None
    ) -> Finding:
        """Update finding"""
        updates = {}
        if status:
            updates['status'] = status
        if assigned_to:
            updates['assigned_to'] = UUID(assigned_to)

        return await finding_service.update(UUID(id), updates)

    @strawberry.mutation
    async def add_comment(
        self,
        finding_id: strawberry.ID,
        content: str
    ) -> Comment:
        """Add comment to finding"""
        return await comment_service.create(
            finding_id=UUID(finding_id),
            content=content
        )

@strawberry.type
class Subscription:
    @strawberry.subscription
    async def finding_updated(
        self,
        finding_id: strawberry.ID
    ) -> AsyncGenerator[Finding, None]:
        """Subscribe to finding updates"""
        async for update in finding_subscription_service.subscribe(UUID(finding_id)):
            yield update

# Create schema
schema = strawberry.Schema(query=Query, mutation=Mutation, subscription=Subscription)

# Add to FastAPI
graphql_app = GraphQLRouter(schema)
app.include_router(graphql_app, prefix="/graphql")
```

**DataLoader for N+1 Prevention**:
```python
# src/api/graphql/dataloaders.py
from strawberry.dataloader import DataLoader

class FindingDataLoader:
    async def load_assignees(self, finding_ids: List[UUID]) -> List[List[User]]:
        """Batch load assignees for findings"""
        assignments = await self.assignment_repo.get_bulk(finding_ids)

        # Group by finding_id
        by_finding = {}
        for assignment in assignments:
            if assignment.finding_id not in by_finding:
                by_finding[assignment.finding_id] = []
            by_finding[assignment.finding_id].append(assignment.user)

        return [by_finding.get(fid, []) for fid in finding_ids]

    async def load_comments(self, finding_ids: List[UUID]) -> List[List[Comment]]:
        """Batch load comments for findings"""
        comments = await self.comment_repo.get_bulk(finding_ids)

        by_finding = {}
        for comment in comments:
            if comment.finding_id not in by_finding:
                by_finding[comment.finding_id] = []
            by_finding[comment.finding_id].append(comment)

        return [by_finding.get(fid, []) for fid in finding_ids]

# Usage in resolver
@strawberry.type
class Finding:
    @strawberry.field
    async def assignees(self, info) -> List[User]:
        loader = info.context.dataloaders['assignees']
        return await loader.load(self.id)
```

**GraphQL Query Examples**:
```graphql
# Query findings with nested data
query GetFindings {
  findings(severity: ["critical", "high"], page: 1, perPage: 10) {
    id
    title
    severity
    status
    contract {
      name
      language
    }
    assignees {
      email
      name
    }
    comments {
      content
      user {
        name
      }
    }
  }
}

# Mutation to update finding
mutation UpdateFinding {
  updateFinding(id: "123", status: "resolved") {
    id
    status
    updatedAt
  }
}

# Subscription for real-time updates
subscription FindingUpdates {
  findingUpdated(findingId: "123") {
    id
    status
    comments {
      content
    }
  }
}
```

**Estimated Time**: 18 hours

**Dependencies**: None

---

#### Task 10.12: API Rate Limiting & Quotas

**Story**: As a platform operator, I need API rate limiting and quotas so that we can ensure fair usage and prevent abuse.

**Acceptance Criteria**:
- [ ] Per-organization API quotas
- [ ] Per-endpoint rate limits
- [ ] Quota usage tracking
- [ ] Quota exceeded notifications
- [ ] Quota reset scheduling
- [ ] Admin quota override capability
- [ ] Usage analytics dashboard
- [ ] Tests for rate limiting

**API Quota System**:
```python
# src/infrastructure/api/quota_manager.py
class APIQuotaManager:
    async def check_quota(
        self,
        organization_id: UUID,
        endpoint: str
    ) -> bool:
        """Check if organization has API quota available"""
        quota = await self.get_organization_quota(organization_id)
        usage = await self.get_current_usage(organization_id)

        if usage.api_calls >= quota.api_calls_limit:
            raise QuotaExceededError(
                f"API call quota exceeded: {usage.api_calls}/{quota.api_calls_limit}"
            )

        # Check endpoint-specific limits
        endpoint_limit = quota.endpoint_limits.get(endpoint)
        if endpoint_limit:
            endpoint_usage = await self.get_endpoint_usage(organization_id, endpoint)
            if endpoint_usage >= endpoint_limit:
                raise EndpointQuotaExceededError(
                    f"Endpoint quota exceeded for {endpoint}: {endpoint_usage}/{endpoint_limit}"
                )

        return True

    async def record_api_call(
        self,
        organization_id: UUID,
        endpoint: str,
        user_id: UUID
    ):
        """Record API call for quota tracking"""
        # Increment Redis counter
        key = f"api_usage:{organization_id}:{date.today()}"
        await self.redis.incr(key)
        await self.redis.expire(key, timedelta(days=32))

        # Increment endpoint-specific counter
        endpoint_key = f"api_usage:{organization_id}:{endpoint}:{date.today()}"
        await self.redis.incr(endpoint_key)
        await self.redis.expire(endpoint_key, timedelta(days=32))

        # Record detailed usage
        await self.usage_repo.create(APIUsageRecord(
            organization_id=organization_id,
            user_id=user_id,
            endpoint=endpoint,
            timestamp=datetime.now()
        ))

# Middleware
class QuotaMiddleware:
    async def __call__(self, request: Request, call_next):
        user = get_current_user()
        if user and not request.url.path.startswith('/api/v1/public'):
            # Check quota
            await quota_manager.check_quota(
                user.organization_id,
                request.url.path
            )

            # Record usage
            await quota_manager.record_api_call(
                user.organization_id,
                request.url.path,
                user.id
            )

        response = await call_next(request)

        # Add quota headers
        if user:
            quota = await quota_manager.get_organization_quota(user.organization_id)
            usage = await quota_manager.get_current_usage(user.organization_id)

            response.headers['X-RateLimit-Limit'] = str(quota.api_calls_limit)
            response.headers['X-RateLimit-Remaining'] = str(quota.api_calls_limit - usage.api_calls)
            response.headers['X-RateLimit-Reset'] = str(quota.reset_at.timestamp())

        return response
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 10.13: API Documentation Portal

**Story**: As an integration developer, I need comprehensive API documentation so that I can integrate with the platform easily.

**Acceptance Criteria**:
- [ ] Interactive API documentation portal
- [ ] Code examples in multiple languages
- [ ] Authentication guide
- [ ] Webhook setup guide
- [ ] Integration tutorials
- [ ] API playground for testing
- [ ] Changelog for API versions
- [ ] Tests for documentation accuracy

**Documentation Portal**:
```typescript
// docs-portal/src/pages/APIDocs.tsx
const APIDocs: React.FC = () => {
  return (
    <DocsLayout>
      <Sidebar>
        <NavSection title="Getting Started">
          <NavLink to="/docs/authentication">Authentication</NavLink>
          <NavLink to="/docs/quickstart">Quickstart</NavLink>
          <NavLink to="/docs/rate-limits">Rate Limits</NavLink>
        </NavSection>

        <NavSection title="API Reference">
          <NavLink to="/docs/api/findings">Findings</NavLink>
          <NavLink to="/docs/api/contracts">Contracts</NavLink>
          <NavLink to="/docs/api/users">Users</NavLink>
          <NavLink to="/docs/api/webhooks">Webhooks</NavLink>
        </NavSection>

        <NavSection title="GraphQL">
          <NavLink to="/docs/graphql/schema">Schema</NavLink>
          <NavLink to="/docs/graphql/queries">Queries</NavLink>
          <NavLink to="/docs/graphql/mutations">Mutations</NavLink>
        </NavSection>

        <NavSection title="SDKs">
          <NavLink to="/docs/sdk/python">Python</NavLink>
          <NavLink to="/docs/sdk/nodejs">Node.js</NavLink>
          <NavLink to="/docs/sdk/ruby">Ruby</NavLink>
        </NavSection>

        <NavSection title="Integrations">
          <NavLink to="/docs/integrations/jira">Jira</NavLink>
          <NavLink to="/docs/integrations/slack">Slack</NavLink>
          <NavLink to="/docs/integrations/teams">Teams</NavLink>
        </NavSection>
      </Sidebar>

      <Content>
        <APIPlayground />
        <CodeExamples />
        <TutorialSection />
      </Content>
    </DocsLayout>
  );
};
```

**Estimated Time**: 14 hours

**Dependencies**: All API tasks

---

## Epic 4: SSO Propagation & Testing

### Epic Goal
Ensure seamless authentication across all integrated systems.

### Tasks

#### Task 10.14: SSO Propagation

**Story**: As a user, I want single sign-on to work across all integrated systems so that I don't have to log in multiple times.

**Acceptance Criteria**:
- [ ] SSO token exchange mechanism
- [ ] OAuth 2.0 token propagation
- [ ] Session synchronization across systems
- [ ] Automatic re-authentication on token expiry
- [ ] SSO for embedded dashboards
- [ ] Logout propagation
- [ ] Security audit of SSO flow
- [ ] Tests for SSO propagation

**Estimated Time**: 12 hours

**Dependencies**: Sprint 9 enterprise authentication tasks

---

#### Task 10.15: Integration Testing & Validation

**Story**: As QA, I need comprehensive integration tests so that we ensure all integrations work reliably.

**Acceptance Criteria**:
- [ ] End-to-end integration tests for all platforms
- [ ] Webhook delivery tests
- [ ] API client library tests
- [ ] GraphQL query tests
- [ ] SSO flow tests
- [ ] Performance tests for API endpoints
- [ ] Integration failure scenario tests
- [ ] All tests passing in CI/CD

**Estimated Time**: 16 hours

**Dependencies**: All integration tasks

---

#### Task 10.16: Production Deployment

**Story**: As DevOps, I need to deploy all integrations to production safely.

**Acceptance Criteria**:
- [ ] Integration configurations deployed
- [ ] Webhook endpoints registered
- [ ] API rate limits configured
- [ ] Monitoring dashboards updated
- [ ] Integration health checks operational
- [ ] Rollback procedures tested
- [ ] Production deployment successful
- [ ] Post-deployment validation passed

**Estimated Time**: 8 hours

**Dependencies**: All previous tasks

---

## Sprint Backlog

### Week 1: ITSM & Communication Integrations

**Monday-Tuesday**: ITSM Integration
- Task 10.1: Jira integration (20h)
- Task 10.2: ServiceNow integration (18h)

**Wednesday**: Ticket Management
- Task 10.3: Ticket lifecycle management (14h)
- Task 10.4: Custom field mapping (12h)

**Thursday-Friday**: Communication Platforms
- Task 10.5: Advanced Microsoft Teams (20h)
- Task 10.6: Salesforce integration (18h)

### Week 2: API & Automation

**Monday**: Slack & Embedding
- Task 10.7: Advanced Slack integration (16h)
- Task 10.8: Dashboard embedding (14h)

**Tuesday-Wednesday**: Enterprise API
- Task 10.9: Comprehensive REST API (16h)
- Task 10.10: Webhook system (16h)
- Task 10.11: GraphQL API (18h)

**Thursday**: API Management
- Task 10.12: API rate limiting & quotas (12h)
- Task 10.13: API documentation portal (14h)

**Friday**: SSO & Testing
- Task 10.14: SSO propagation (12h)
- Task 10.15: Integration testing (16h)
- Task 10.16: Production deployment (8h)

**Total Estimated Hours**: 254 hours (Team of 5 engineers x 2 weeks = 400 hours available)

---

## Acceptance Criteria Summary

### ITSM Integration
- [x] Findings automatically create tickets in Jira and ServiceNow
- [x] Bidirectional status synchronization working reliably
- [x] Comment synchronization prevents duplication
- [x] Custom field mapping configured per organization
- [x] Webhook handlers process updates correctly

### Communication Platforms
- [x] Microsoft Teams provides interactive finding management
- [x] Salesforce tracks customer security posture
- [x] Slack slash commands and shortcuts functional
- [x] Dashboard embedding secure and performant
- [x] SSO propagates seamlessly to integrated systems

### Enterprise API
- [x] REST API complete with comprehensive filtering
- [x] GraphQL API enables efficient data fetching
- [x] Webhooks deliver events reliably with retry
- [x] API client libraries simplify integration
- [x] API documentation comprehensive and accurate

### Integration Quality
- [x] All integrations handle enterprise-scale loads
- [x] Integration failures gracefully degraded
- [x] API rate limiting prevents abuse
- [x] SSO works across all integrated systems
- [x] Comprehensive testing validates all integrations

---

## Risks & Mitigation

### Risk 1: Integration Platform API Changes
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- Version pinning for external APIs
- Comprehensive error handling
- Fallback mechanisms for deprecated features
- Monitoring for API deprecation notices

### Risk 2: Webhook Delivery Reliability
**Impact**: High
**Probability**: Low
**Mitigation**:
- Retry logic with exponential backoff
- Dead letter queue for failed deliveries
- Monitoring and alerting for delivery failures
- Manual retry capability

### Risk 3: SSO Complexity Across Systems
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Comprehensive testing of SSO flows
- Clear documentation for setup
- Fallback to direct authentication
- Dedicated support for SSO issues

### Risk 4: API Performance Under Load
**Impact**: Medium
**Probability**: Low
**Mitigation**:
- Comprehensive load testing
- Rate limiting and throttling
- Caching strategies
- Database query optimization

---

## Success Metrics

### Integration Adoption
- ITSM integration usage: >70% of enterprise customers
- Webhook subscriptions: >50 per organization on average
- API calls per day: >100,000 across platform
- Dashboard embeds: >30% of customers

### Integration Performance
- Webhook delivery success rate: >99%
- Ticket sync latency: <5 seconds
- API response time P95: <200ms
- GraphQL query efficiency: >80% reduction vs REST

### Business Impact
- Context switching reduction: -60%
- Integration setup time: <2 hours
- Customer satisfaction with integrations: >4.5/5
- Enterprise customer retention: +15%

---

## Documentation

### Integration Guides
- Jira Setup: `/Users/pwner/Git/ABS/docs/integrations/jira-integration.md`
- ServiceNow Setup: `/Users/pwner/Git/ABS/docs/integrations/servicenow-integration.md`
- Teams Integration: `/Users/pwner/Git/ABS/docs/integrations/teams-integration.md`
- Salesforce Setup: `/Users/pwner/Git/ABS/docs/integrations/salesforce-integration.md`

### API Documentation
- REST API Reference: `/Users/pwner/Git/ABS/docs/api/rest-api-reference.md`
- GraphQL Schema: `/Users/pwner/Git/ABS/docs/api/graphql-schema.md`
- Webhook Guide: `/Users/pwner/Git/ABS/docs/api/webhooks.md`
- SDK Documentation: `/Users/pwner/Git/ABS/docs/sdk/`

### Developer Resources
- API Quickstart: `/Users/pwner/Git/ABS/docs/developers/api-quickstart.md`
- Integration Patterns: `/Users/pwner/Git/ABS/docs/developers/integration-patterns.md`
- Webhook Best Practices: `/Users/pwner/Git/ABS/docs/developers/webhook-best-practices.md`

---

## Dependencies

### External Platforms
- Jira Cloud/Server
- ServiceNow
- Microsoft Teams
- Slack
- Salesforce

### Infrastructure
- Redis for webhook queue
- PostgreSQL for integration data
- Message queue for async processing

### Internal Systems
- Authentication service
- API gateway
- Notification service
- Analytics service

---

## Future Enhancements (Post-Sprint 10)

### Sprint 11+
- Additional ITSM platforms (Azure DevOps, Linear)
- More communication platforms (Discord, Mattermost)
- CRM integrations (HubSpot, Zendesk)
- CI/CD integrations (GitHub Actions, GitLab CI)
- Custom webhook transformations
- API analytics and insights
- Integration marketplace
- No-code integration builder
- Advanced workflow automation
- Machine learning for integration optimization

---

**Sprint 10 Team**: Backend (3), Frontend (1), DevOps (1), Integration Engineer (1), Technical Writer (1)
**Sprint Goal**: Complete enterprise ecosystem integration with automated workflows and comprehensive APIs
**Definition of Done**: All integrations functional, APIs comprehensive, webhooks delivering reliably, SSO working across systems, production deployment successful
