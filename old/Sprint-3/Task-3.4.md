# Task 3.4: Email and Integration Services

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 4 hours
**Owner**: Full Stack Team
**Priority**: P1 (High)
**Repository**: `blocksecops-notification`

## Overview

Develop comprehensive communication integration services for the Apogee Platform, including secure email delivery with professional templates, Slack integration for team collaboration, and generic webhook support for external integrations. This task extends the notification service with production-ready communication channels while maintaining local-first development principles.

## Technical Requirements

### Technology Stack
```yaml
Runtime: Node.js 20 LTS with native TypeScript support
Email: SMTP client with secure authentication
Templates: Professional email templates with responsive design
Slack: Official Slack SDK for workspace integration
Webhooks: Generic webhook client for external services
Rate Limiting: Protection against notification spam
Analytics: Delivery tracking and notification metrics
```

### Development Standards
- **Local-First Development**: All services tested in local minikube environment
- **Security First**: Secure credential management via HashiCorp Vault
- **Rate Limiting**: Intelligent rate limiting to prevent notification flooding
- **Retry Logic**: Exponential backoff for failed deliveries
- **Template System**: Professional, branded email templates
- **Analytics**: Comprehensive delivery tracking and insights

## Communication Integration Architecture

### SMTP Integration
```typescript
// src/services/email/smtp-client.ts
import nodemailer from 'nodemailer';
import { EmailTemplate } from './templates/email-template';
import { VaultService } from '../security/vault-service';

interface SMTPConfig {
  host: string;
  port: number;
  secure: boolean;
  auth: {
    user: string;
    pass: string;
  };
}

export class SMTPClient {
  private transporter: nodemailer.Transporter;
  private vaultService: VaultService;

  constructor(vaultService: VaultService) {
    this.vaultService = vaultService;
  }

  async initialize(): Promise<void> {
    const smtpConfig = await this.vaultService.getSecret('local/notification/smtp');

    this.transporter = nodemailer.createTransporter({
      host: smtpConfig.host,
      port: smtpConfig.port,
      secure: smtpConfig.secure,
      auth: {
        user: smtpConfig.user,
        pass: smtpConfig.password
      },
      pool: true,
      maxConnections: 5,
      maxMessages: 100
    });
  }

  async sendEmail(
    to: string | string[],
    template: EmailTemplate,
    variables: Record<string, any>
  ): Promise<boolean> {
    try {
      const renderedTemplate = await template.render(variables);

      const mailOptions = {
        from: `"Apogee Platform" <noreply@advancedblockchainsecurity.com>`,
        to: Array.isArray(to) ? to.join(', ') : to,
        subject: renderedTemplate.subject,
        html: renderedTemplate.html,
        text: renderedTemplate.text
      };

      const result = await this.transporter.sendMail(mailOptions);
      return result.accepted.length > 0;
    } catch (error) {
      console.error('Email delivery failed:', error);
      return false;
    }
  }

  async verifyConnection(): Promise<boolean> {
    try {
      await this.transporter.verify();
      return true;
    } catch (error) {
      console.error('SMTP connection verification failed:', error);
      return false;
    }
  }
}
```

### Professional Email Templates
```typescript
// src/services/email/templates/base-template.ts
import Handlebars from 'handlebars';
import { readFileSync } from 'fs';
import { join } from 'path';

export interface RenderedTemplate {
  subject: string;
  html: string;
  text: string;
}

export abstract class EmailTemplate {
  protected templateName: string;
  protected subjectTemplate: HandlebarsTemplateDelegate;
  protected htmlTemplate: HandlebarsTemplateDelegate;
  protected textTemplate: HandlebarsTemplateDelegate;

  constructor(templateName: string) {
    this.templateName = templateName;
    this.loadTemplates();
  }

  private loadTemplates(): void {
    const templateDir = join(__dirname, 'templates', this.templateName);

    const subjectSource = readFileSync(join(templateDir, 'subject.hbs'), 'utf-8');
    const htmlSource = readFileSync(join(templateDir, 'body.html.hbs'), 'utf-8');
    const textSource = readFileSync(join(templateDir, 'body.text.hbs'), 'utf-8');

    this.subjectTemplate = Handlebars.compile(subjectSource);
    this.htmlTemplate = Handlebars.compile(htmlSource);
    this.textTemplate = Handlebars.compile(textSource);
  }

  async render(variables: Record<string, any>): Promise<RenderedTemplate> {
    const context = {
      ...variables,
      platformName: 'Apogee Platform',
      supportEmail: 'support@advancedblockchainsecurity.com',
      currentYear: new Date().getFullYear(),
      logoUrl: 'https://app.advancedblockchainsecurity.com/assets/logo.png'
    };

    return {
      subject: this.subjectTemplate(context),
      html: this.htmlTemplate(context),
      text: this.textTemplate(context)
    };
  }
}

// Critical Security Finding Template
export class CriticalFindingTemplate extends EmailTemplate {
  constructor() {
    super('critical-finding');
  }
}

// Analysis Complete Template
export class AnalysisCompleteTemplate extends EmailTemplate {
  constructor() {
    super('analysis-complete');
  }
}

// Weekly Security Report Template
export class WeeklyReportTemplate extends EmailTemplate {
  constructor() {
    super('weekly-report');
  }
}

// User Welcome Template
export class WelcomeTemplate extends EmailTemplate {
  constructor() {
    super('welcome');
  }
}

// Password Reset Template
export class PasswordResetTemplate extends EmailTemplate {
  constructor() {
    super('password-reset');
  }
}
```

### Slack Integration
```typescript
// src/services/slack/slack-client.ts
import { WebClient, ChatPostMessageArguments } from '@slack/web-api';
import { VaultService } from '../security/vault-service';

interface SlackConfig {
  botToken: string;
  signingSecret: string;
  defaultChannel: string;
}

export class SlackClient {
  private client: WebClient;
  private config: SlackConfig;

  constructor(private vaultService: VaultService) {}

  async initialize(): Promise<void> {
    this.config = await this.vaultService.getSecret('local/notification/slack');
    this.client = new WebClient(this.config.botToken);
  }

  async sendChannelMessage(
    channel: string,
    message: string,
    attachments?: any[]
  ): Promise<boolean> {
    try {
      const result = await this.client.chat.postMessage({
        channel: channel || this.config.defaultChannel,
        text: message,
        attachments,
        as_user: false,
        username: 'Apogee Bot',
        icon_emoji: ':shield:'
      });

      return result.ok;
    } catch (error) {
      console.error('Slack message delivery failed:', error);
      return false;
    }
  }

  async sendDirectMessage(
    userId: string,
    message: string
  ): Promise<boolean> {
    try {
      const result = await this.client.chat.postMessage({
        channel: userId,
        text: message,
        as_user: false,
        username: 'Apogee Bot',
        icon_emoji: ':shield:'
      });

      return result.ok;
    } catch (error) {
      console.error('Slack DM delivery failed:', error);
      return false;
    }
  }

  async notifyCriticalFinding(
    channel: string,
    finding: any,
    projectName: string
  ): Promise<boolean> {
    const attachment = {
      color: 'danger',
      title: `🚨 Critical Security Finding Detected`,
      fields: [
        {
          title: 'Project',
          value: projectName,
          short: true
        },
        {
          title: 'Severity',
          value: finding.severity.toUpperCase(),
          short: true
        },
        {
          title: 'Finding',
          value: finding.title,
          short: false
        },
        {
          title: 'Tool',
          value: finding.tool_source,
          short: true
        },
        {
          title: 'Location',
          value: `${finding.location.file}:${finding.location.line}`,
          short: true
        }
      ],
      timestamp: Math.floor(Date.now() / 1000)
    };

    return this.sendChannelMessage(
      channel,
      'A critical security vulnerability has been detected in your Solidity code.',
      [attachment]
    );
  }
}
```

### Generic Webhook Client
```typescript
// src/services/webhooks/webhook-client.ts
import axios, { AxiosResponse } from 'axios';
import crypto from 'crypto';

interface WebhookConfig {
  url: string;
  secret?: string;
  headers?: Record<string, string>;
  retryAttempts: number;
  timeout: number;
}

interface WebhookPayload {
  event: string;
  timestamp: number;
  data: any;
  signature?: string;
}

export class WebhookClient {
  private config: WebhookConfig;

  constructor(config: WebhookConfig) {
    this.config = {
      retryAttempts: 3,
      timeout: 10000,
      ...config
    };
  }

  async sendWebhook(
    event: string,
    data: any,
    retryCount: number = 0
  ): Promise<boolean> {
    try {
      const payload: WebhookPayload = {
        event,
        timestamp: Date.now(),
        data
      };

      // Generate signature if secret is provided
      if (this.config.secret) {
        const hmac = crypto.createHmac('sha256', this.config.secret);
        hmac.update(JSON.stringify(payload));
        payload.signature = hmac.digest('hex');
      }

      const headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'Solidity-Security-Platform/1.0',
        ...this.config.headers
      };

      if (payload.signature) {
        headers['X-Signature-SHA256'] = `sha256=${payload.signature}`;
      }

      const response: AxiosResponse = await axios.post(
        this.config.url,
        payload,
        {
          headers,
          timeout: this.config.timeout,
          validateStatus: (status) => status >= 200 && status < 300
        }
      );

      return true;
    } catch (error) {
      console.error(`Webhook delivery failed (attempt ${retryCount + 1}):`, error);

      if (retryCount < this.config.retryAttempts) {
        // Exponential backoff
        const delay = Math.pow(2, retryCount) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
        return this.sendWebhook(event, data, retryCount + 1);
      }

      return false;
    }
  }

  async validateWebhook(): Promise<boolean> {
    try {
      const testPayload = {
        event: 'webhook.test',
        timestamp: Date.now(),
        data: { test: true }
      };

      const response = await axios.post(this.config.url, testPayload, {
        timeout: 5000,
        validateStatus: (status) => status >= 200 && status < 500 // Accept 4xx as valid endpoint
      });

      return true;
    } catch (error) {
      return false;
    }
  }
}
```

### Rate Limiting Service
```typescript
// src/services/rate-limiting/rate-limiter.ts
import Redis from 'ioredis';

interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
  identifier: string;
}

export class RateLimiter {
  private redis: Redis;

  constructor(redisUrl: string) {
    this.redis = new Redis(redisUrl);
  }

  async checkRateLimit(config: RateLimitConfig): Promise<{
    allowed: boolean;
    remaining: number;
    resetTime: number;
  }> {
    const key = `rate_limit:${config.identifier}`;
    const now = Date.now();
    const windowStart = now - config.windowMs;

    // Remove old entries
    await this.redis.zremrangebyscore(key, 0, windowStart);

    // Count current requests
    const currentCount = await this.redis.zcard(key);

    if (currentCount < config.maxRequests) {
      // Add current request
      await this.redis.zadd(key, now, `${now}-${Math.random()}`);
      await this.redis.expire(key, Math.ceil(config.windowMs / 1000));

      return {
        allowed: true,
        remaining: config.maxRequests - currentCount - 1,
        resetTime: now + config.windowMs
      };
    }

    return {
      allowed: false,
      remaining: 0,
      resetTime: now + config.windowMs
    };
  }
}
```

### Notification Analytics Service
```typescript
// src/services/analytics/notification-analytics.ts
import { DatabaseService } from '../database/database-service';

interface DeliveryMetrics {
  channel: string;
  sent: number;
  delivered: number;
  failed: number;
  deliveryRate: number;
}

export class NotificationAnalytics {
  constructor(private db: DatabaseService) {}

  async trackDelivery(
    notificationId: string,
    channel: 'email' | 'slack' | 'webhook',
    status: 'sent' | 'delivered' | 'failed',
    metadata?: any
  ): Promise<void> {
    await this.db.notification_events.create({
      notification_id: notificationId,
      channel,
      status,
      metadata: metadata || {},
      timestamp: new Date()
    });
  }

  async getDeliveryMetrics(
    startDate: Date,
    endDate: Date
  ): Promise<DeliveryMetrics[]> {
    const metrics = await this.db.query(`
      SELECT
        channel,
        COUNT(*) as sent,
        COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
        ROUND(
          COUNT(CASE WHEN status = 'delivered' THEN 1 END) * 100.0 / COUNT(*),
          2
        ) as delivery_rate
      FROM notification_events
      WHERE timestamp BETWEEN $1 AND $2
      GROUP BY channel
    `, [startDate, endDate]);

    return metrics.rows;
  }

  async getFailureAnalysis(channel: string): Promise<any[]> {
    const failures = await this.db.query(`
      SELECT
        metadata->>'error_type' as error_type,
        COUNT(*) as count,
        array_agg(DISTINCT metadata->>'error_message') as error_messages
      FROM notification_events
      WHERE channel = $1 AND status = 'failed'
      GROUP BY metadata->>'error_type'
      ORDER BY count DESC
    `, [channel]);

    return failures.rows;
  }
}
```

## Integrated Notification Service

### Main Notification Service
```typescript
// src/services/notification-service.ts
import { SMTPClient } from './email/smtp-client';
import { SlackClient } from './slack/slack-client';
import { WebhookClient } from './webhooks/webhook-client';
import { RateLimiter } from './rate-limiting/rate-limiter';
import { NotificationAnalytics } from './analytics/notification-analytics';
import { VaultService } from './security/vault-service';

interface NotificationRequest {
  type: 'email' | 'slack' | 'webhook';
  recipients: string[];
  template?: string;
  data: any;
  priority: 'low' | 'normal' | 'high' | 'critical';
}

export class NotificationService {
  private smtp: SMTPClient;
  private slack: SlackClient;
  private webhookClients: Map<string, WebhookClient>;
  private rateLimiter: RateLimiter;
  private analytics: NotificationAnalytics;

  constructor(
    vaultService: VaultService,
    redisUrl: string,
    analytics: NotificationAnalytics
  ) {
    this.smtp = new SMTPClient(vaultService);
    this.slack = new SlackClient(vaultService);
    this.webhookClients = new Map();
    this.rateLimiter = new RateLimiter(redisUrl);
    this.analytics = analytics;
  }

  async initialize(): Promise<void> {
    await Promise.all([
      this.smtp.initialize(),
      this.slack.initialize()
    ]);
  }

  async sendNotification(request: NotificationRequest): Promise<boolean> {
    const notificationId = `notif_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Check rate limits
    const rateLimitCheck = await this.rateLimiter.checkRateLimit({
      windowMs: 60000, // 1 minute
      maxRequests: this.getPriorityLimit(request.priority),
      identifier: `${request.type}_${request.recipients.join(',')}`
    });

    if (!rateLimitCheck.allowed) {
      console.warn('Rate limit exceeded for notification:', request);
      return false;
    }

    try {
      let success = false;

      switch (request.type) {
        case 'email':
          success = await this.sendEmail(request);
          break;
        case 'slack':
          success = await this.sendSlack(request);
          break;
        case 'webhook':
          success = await this.sendWebhook(request);
          break;
      }

      await this.analytics.trackDelivery(
        notificationId,
        request.type,
        success ? 'delivered' : 'failed',
        { priority: request.priority, recipients: request.recipients.length }
      );

      return success;
    } catch (error) {
      await this.analytics.trackDelivery(
        notificationId,
        request.type,
        'failed',
        { error: error.message, priority: request.priority }
      );
      return false;
    }
  }

  private getPriorityLimit(priority: string): number {
    const limits = {
      low: 10,
      normal: 30,
      high: 60,
      critical: 100
    };
    return limits[priority] || 30;
  }

  private async sendEmail(request: NotificationRequest): Promise<boolean> {
    // Implementation for email sending using templates
    return this.smtp.sendEmail(request.recipients, /* template */, request.data);
  }

  private async sendSlack(request: NotificationRequest): Promise<boolean> {
    // Implementation for Slack messaging
    for (const recipient of request.recipients) {
      await this.slack.sendChannelMessage(recipient, request.data.message);
    }
    return true;
  }

  private async sendWebhook(request: NotificationRequest): Promise<boolean> {
    // Implementation for webhook delivery
    const webhook = this.webhookClients.get(request.recipients[0]);
    if (webhook) {
      return webhook.sendWebhook(request.data.event, request.data);
    }
    return false;
  }
}
```

## Local-First Development Configuration

### Development Environment Setup
```yaml
# docker-compose.local.yml
version: '3.8'
services:
  notification-service:
    build:
      context: .
      dockerfile: Dockerfile.local
    environment:
      - NODE_ENV=development
      - REDIS_URL=redis://redis:6379
      - VAULT_ADDR=http://vault:8200
      - VAULT_TOKEN=${VAULT_DEV_ROOT_TOKEN_ID}
    ports:
      - "3003:3000"
    depends_on:
      - redis
      - vault
    volumes:
      - ./src:/app/src
      - ./templates:/app/templates

  mailhog:
    image: mailhog/mailhog:v1.0.1
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI
    environment:
      - MH_STORAGE=maildir
      - MH_MAILDIR_PATH=/maildir
    volumes:
      - mailhog_data:/maildir

volumes:
  mailhog_data:
```

### Local SMTP Configuration
```typescript
// config/local.ts
export const localConfig = {
  smtp: {
    host: 'mailhog',
    port: 1025,
    secure: false,
    auth: {
      user: 'test',
      pass: 'test'
    }
  },
  slack: {
    enabled: false, // Disable in local development
    botToken: 'xoxb-test-token',
    defaultChannel: '#general-test'
  },
  webhooks: {
    enabled: true,
    testEndpoint: 'http://webhook-test:3000/webhook'
  }
};
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Code Structure
```
src/
├── services/
│   ├── email/
│   │   ├── smtp-client.ts         # SMTP client implementation
│   │   ├── templates/             # Email template system
│   │   │   ├── base-template.ts   # Base template class
│   │   │   ├── critical-finding/  # Critical finding templates
│   │   │   ├── analysis-complete/ # Analysis completion templates
│   │   │   ├── weekly-report/     # Weekly report templates
│   │   │   ├── welcome/          # User welcome templates
│   │   │   └── password-reset/   # Password reset templates
│   │   └── email-service.ts      # High-level email service
│   ├── slack/
│   │   ├── slack-client.ts       # Slack SDK integration
│   │   └── slack-service.ts      # Slack notification service
│   ├── webhooks/
│   │   ├── webhook-client.ts     # Generic webhook client
│   │   └── webhook-service.ts    # Webhook management service
│   ├── rate-limiting/
│   │   └── rate-limiter.ts       # Redis-based rate limiting
│   ├── analytics/
│   │   └── notification-analytics.ts # Delivery tracking
│   └── notification-service.ts    # Main notification orchestrator
├── templates/                     # Email template files
├── config/                       # Environment configurations
├── types/                        # TypeScript type definitions
└── tests/                        # Comprehensive test suite
```

### Email Templates Implemented
- **Critical Security Finding Notifications**: Immediate alerts for high-severity vulnerabilities
- **Analysis Completion Summaries**: Comprehensive analysis results with findings overview
- **Weekly Security Reports**: Scheduled reports with security metrics and trends
- **User Onboarding and Welcome Emails**: Professional welcome sequence for new users
- **Password Reset and Security Notifications**: Account security communications

### Features Implemented
- ✅ Secure SMTP client with authentication and connection pooling
- ✅ Professional email template system with responsive design
- ✅ Slack integration with channel and direct message support
- ✅ Generic webhook client with retry logic and signature validation
- ✅ Redis-based rate limiting with priority-aware limits
- ✅ Comprehensive delivery tracking and analytics
- ✅ Local-first development with MailHog for email testing
- ✅ HashiCorp Vault integration for secure credential management

## Acceptance Criteria

### Email Delivery
- [ ] Email delivery functional with professional branded templates
- [ ] SMTP authentication working with secure credential storage
- [ ] Email templates render correctly across major email clients
- [ ] Delivery tracking captures sent, delivered, and failed states
- [ ] Rate limiting prevents email flooding while allowing critical notifications

### Slack Integration
- [ ] Slack notifications integrate seamlessly with workspace channels
- [ ] Direct message delivery working for individual user notifications
- [ ] Critical finding alerts format properly with rich attachments
- [ ] Bot authentication and permissions configured correctly
- [ ] Rate limiting respects Slack API limits and guidelines

### Webhook Support
- [ ] Webhook deliveries include proper authentication and validation
- [ ] Retry logic implements exponential backoff for failed deliveries
- [ ] Signature generation and validation working correctly
- [ ] Generic webhook format supports various external integrations
- [ ] Webhook validation endpoint confirms connectivity

### Performance and Reliability
- [ ] Rate limiting prevents notification flooding while maintaining functionality
- [ ] Failed deliveries retry with exponential backoff up to configured limits
- [ ] Notification analytics provide comprehensive delivery insights
- [ ] Local development environment supports full testing workflow
- [ ] All services integrate with HashiCorp Vault for credential management

This task establishes a comprehensive communication infrastructure that enables professional, reliable, and secure notifications across multiple channels while maintaining the platform's local-first development approach.