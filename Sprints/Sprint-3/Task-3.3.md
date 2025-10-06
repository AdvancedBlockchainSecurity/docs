# Task 3.3: WebSocket Server Implementation

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 6 hours
**Owner**: Full Stack Team
**Priority**: P0 (Critical)
**Repository**: `solidity-security-notification`

## Overview

Implement a high-performance WebSocket server using Node.js 20 LTS and Socket.IO for real-time communication. This service will handle real-time notifications, analysis progress updates, and system events across the Solidity Security Platform.

## Technical Requirements

### Technology Stack
```yaml
Runtime: Node.js 20 LTS with native TypeScript support
WebSocket: Socket.IO 4.7+ with Redis adapter for scalability
Framework: Express.js 4.18+ for HTTP endpoints
Authentication: JWT verification middleware
Message Queue: Redis 7.2 for event distribution
Monitoring: Prometheus metrics for connection monitoring
Database: PostgreSQL integration for user preferences
```

### Performance Standards
- **Concurrent Connections**: Support 1000+ simultaneous connections per instance
- **Message Latency**: Sub-100ms message delivery
- **Connection Stability**: Automatic reconnection with exponential backoff
- **Scalability**: Horizontal scaling across multiple instances
- **Memory Efficiency**: Optimized memory usage with connection pooling

### Security Requirements
- **Secret Management**: ALL secrets (JWT_SECRET, Redis passwords, etc.) MUST be stored in Vault and pulled via External Secrets Operator
- **No Hardcoded Secrets**: Environment variables loaded from Kubernetes secrets managed by ExternalSecret resources
- **Vault Integration**: Service account authentication with Vault policies for secret access

## Real-Time Architecture Design

### WebSocket Event System
```typescript
// src/types/events.ts
export interface AnalysisEvents {
  'analysis:started': {
    analysisId: string;
    projectId: string;
    userId: string;
    toolsCount: number;
    estimatedDuration: number;
  };

  'analysis:progress': {
    analysisId: string;
    projectId: string;
    progress: number; // 0-100
    currentTool: string;
    completedTools: string[];
    message: string;
    timestamp: Date;
  };

  'analysis:tool_completed': {
    analysisId: string;
    projectId: string;
    toolName: string;
    findingsCount: number;
    duration: number;
    status: 'success' | 'failed' | 'timeout';
  };

  'analysis:completed': {
    analysisId: string;
    projectId: string;
    status: 'success' | 'failed' | 'cancelled';
    results: AnalysisResults;
    duration: number;
    findingSummary: FindingSummary;
  };

  'finding:new': {
    findingId: string;
    analysisId: string;
    projectId: string;
    severity: 'critical' | 'high' | 'medium' | 'low' | 'info';
    category: string;
    title: string;
    toolSource: string;
  };

  'finding:updated': {
    findingId: string;
    projectId: string;
    status: string;
    assignedTo?: string;
    updatedBy: string;
  };

  'system:notification': {
    type: 'info' | 'warning' | 'error' | 'success';
    message: string;
    userId?: string;
    projectId?: string;
    autoClose?: boolean;
    duration?: number;
  };

  'user:presence': {
    userId: string;
    status: 'online' | 'offline' | 'away';
    projectId?: string;
  };
}

export interface FindingSummary {
  total: number;
  critical: number;
  high: number;
  medium: number;
  low: number;
  info: number;
}

export interface AnalysisResults {
  totalFindings: number;
  toolResults: ToolResult[];
  duration: number;
  status: string;
}
```

### Socket.IO Server Implementation
```typescript
// src/websocket/server.ts
import { Server as SocketIOServer } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';
import jwt from 'jsonwebtoken';
import { Server as HTTPServer } from 'http';
import { ConnectionManager } from './connection-manager';
import { RoomManager } from './room-manager';
import { EventHandlers } from './event-handlers';
import { AuthMiddleware } from './middleware/auth';
import { logger } from '../utils/logger';

export class WebSocketServer {
  private io: SocketIOServer;
  private connectionManager: ConnectionManager;
  private roomManager: RoomManager;
  private eventHandlers: EventHandlers;

  constructor(server: HTTPServer, redisUrl: string) {
    // Initialize Socket.IO server
    this.io = new SocketIOServer(server, {
      cors: {
        origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],
        credentials: true,
      },
      transports: ['polling', 'websocket'],
      allowEIO3: false,
      pingTimeout: 60000,
      pingInterval: 25000,
    });

    // Redis adapter for scaling across multiple instances
    this.setupRedisAdapter(redisUrl);

    // Initialize managers
    this.connectionManager = new ConnectionManager(this.io);
    this.roomManager = new RoomManager(this.io);
    this.eventHandlers = new EventHandlers(this.io, this.roomManager);

    // Setup authentication middleware
    this.setupAuthentication();

    // Setup event handlers
    this.setupEventHandlers();

    logger.info('WebSocket server initialized');
  }

  private async setupRedisAdapter(redisUrl: string): Promise<void> {
    try {
      const pubClient = createClient({ url: redisUrl });
      const subClient = pubClient.duplicate();

      await Promise.all([pubClient.connect(), subClient.connect()]);

      this.io.adapter(createAdapter(pubClient, subClient));
      logger.info('Redis adapter configured for Socket.IO');
    } catch (error) {
      logger.error('Failed to setup Redis adapter:', error);
      throw error;
    }
  }

  private setupAuthentication(): void {
    this.io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');

        if (!token) {
          return next(new Error('Authentication token required'));
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
        socket.data.user = {
          id: decoded.sub,
          email: decoded.email,
          roles: decoded.roles || [],
        };

        logger.debug(`User ${decoded.sub} authenticated for WebSocket connection`);
        next();
      } catch (error) {
        logger.warn('WebSocket authentication failed:', error);
        next(new Error('Invalid authentication token'));
      }
    });
  }

  private setupEventHandlers(): void {
    this.io.on('connection', (socket) => {
      const userId = socket.data.user.id;
      logger.info(`User ${userId} connected to WebSocket`);

      // Register connection
      this.connectionManager.addConnection(socket);

      // Join user-specific room
      this.roomManager.joinUserRoom(socket, userId);

      // Handle client events
      socket.on('join:project', (projectId: string) => {
        this.roomManager.joinProjectRoom(socket, projectId);
      });

      socket.on('leave:project', (projectId: string) => {
        this.roomManager.leaveProjectRoom(socket, projectId);
      });

      socket.on('user:presence', (status: 'online' | 'away') => {
        this.eventHandlers.handlePresenceUpdate(socket, status);
      });

      socket.on('disconnect', (reason) => {
        logger.info(`User ${userId} disconnected: ${reason}`);
        this.connectionManager.removeConnection(socket);
        this.eventHandlers.handleDisconnection(socket);
      });

      socket.on('error', (error) => {
        logger.error(`Socket error for user ${userId}:`, error);
      });
    });
  }

  public getIO(): SocketIOServer {
    return this.io;
  }

  public async close(): Promise<void> {
    this.io.close();
    logger.info('WebSocket server closed');
  }
}
```

### Connection Management
```typescript
// src/websocket/connection-manager.ts
import { Socket } from 'socket.io';
import { metrics } from '../monitoring/metrics';

export class ConnectionManager {
  private connections = new Map<string, Socket>();
  private userConnections = new Map<string, Set<string>>();

  constructor(private io: any) {}

  addConnection(socket: Socket): void {
    const socketId = socket.id;
    const userId = socket.data.user.id;

    this.connections.set(socketId, socket);

    // Track user connections (users can have multiple connections)
    if (!this.userConnections.has(userId)) {
      this.userConnections.set(userId, new Set());
    }
    this.userConnections.get(userId)!.add(socketId);

    // Update metrics
    metrics.activeConnections.inc();
    metrics.connectedUsers.set(this.userConnections.size);

    logger.debug(`Connection added: ${socketId} for user ${userId}`);
  }

  removeConnection(socket: Socket): void {
    const socketId = socket.id;
    const userId = socket.data.user?.id;

    this.connections.delete(socketId);

    if (userId && this.userConnections.has(userId)) {
      const userSockets = this.userConnections.get(userId)!;
      userSockets.delete(socketId);

      if (userSockets.size === 0) {
        this.userConnections.delete(userId);
      }
    }

    // Update metrics
    metrics.activeConnections.dec();
    metrics.connectedUsers.set(this.userConnections.size);

    logger.debug(`Connection removed: ${socketId}`);
  }

  getConnectionsForUser(userId: string): Socket[] {
    const socketIds = this.userConnections.get(userId) || new Set();
    return Array.from(socketIds)
      .map(id => this.connections.get(id))
      .filter(socket => socket !== undefined) as Socket[];
  }

  getTotalConnections(): number {
    return this.connections.size;
  }

  getTotalUsers(): number {
    return this.userConnections.size;
  }

  isUserConnected(userId: string): boolean {
    return this.userConnections.has(userId);
  }

  getConnectionStats() {
    return {
      totalConnections: this.getTotalConnections(),
      totalUsers: this.getTotalUsers(),
      connectionsPerUser: this.getTotalConnections() / Math.max(this.getTotalUsers(), 1),
    };
  }
}
```

### Room Management for Real-Time Updates
```typescript
// src/websocket/room-manager.ts
import { Socket } from 'socket.io';
import { logger } from '../utils/logger';

export class RoomManager {
  private userRooms = new Map<string, Set<string>>(); // userId -> roomIds
  private projectRooms = new Map<string, Set<string>>(); // projectId -> userIds

  constructor(private io: any) {}

  joinUserRoom(socket: Socket, userId: string): void {
    const roomId = `user:${userId}`;
    socket.join(roomId);

    if (!this.userRooms.has(userId)) {
      this.userRooms.set(userId, new Set());
    }
    this.userRooms.get(userId)!.add(roomId);

    logger.debug(`User ${userId} joined room ${roomId}`);
  }

  joinProjectRoom(socket: Socket, projectId: string): void {
    const userId = socket.data.user.id;
    const roomId = `project:${projectId}`;

    socket.join(roomId);

    // Track project room membership
    if (!this.projectRooms.has(projectId)) {
      this.projectRooms.set(projectId, new Set());
    }
    this.projectRooms.get(projectId)!.add(userId);

    // Track user's project rooms
    if (!this.userRooms.has(userId)) {
      this.userRooms.set(userId, new Set());
    }
    this.userRooms.get(userId)!.add(roomId);

    logger.debug(`User ${userId} joined project room ${roomId}`);

    // Notify other users in the project
    socket.to(roomId).emit('user:joined_project', {
      userId,
      projectId,
      timestamp: new Date(),
    });
  }

  leaveProjectRoom(socket: Socket, projectId: string): void {
    const userId = socket.data.user.id;
    const roomId = `project:${projectId}`;

    socket.leave(roomId);

    // Remove from project room tracking
    if (this.projectRooms.has(projectId)) {
      this.projectRooms.get(projectId)!.delete(userId);
      if (this.projectRooms.get(projectId)!.size === 0) {
        this.projectRooms.delete(projectId);
      }
    }

    // Remove from user's room list
    if (this.userRooms.has(userId)) {
      this.userRooms.get(userId)!.delete(roomId);
    }

    logger.debug(`User ${userId} left project room ${roomId}`);

    // Notify other users in the project
    socket.to(roomId).emit('user:left_project', {
      userId,
      projectId,
      timestamp: new Date(),
    });
  }

  getUsersInProject(projectId: string): string[] {
    return Array.from(this.projectRooms.get(projectId) || new Set());
  }

  getProjectsForUser(userId: string): string[] {
    const rooms = this.userRooms.get(userId) || new Set();
    return Array.from(rooms)
      .filter(room => room.startsWith('project:'))
      .map(room => room.replace('project:', ''));
  }

  broadcastToUser(userId: string, event: string, data: any): void {
    const roomId = `user:${userId}`;
    this.io.to(roomId).emit(event, data);
    logger.debug(`Broadcast to user ${userId}: ${event}`);
  }

  broadcastToProject(projectId: string, event: string, data: any): void {
    const roomId = `project:${projectId}`;
    this.io.to(roomId).emit(event, data);
    logger.debug(`Broadcast to project ${projectId}: ${event}`);
  }

  broadcastToAll(event: string, data: any): void {
    this.io.emit(event, data);
    logger.debug(`Broadcast to all: ${event}`);
  }
}
```

### Event Handlers for Business Logic
```typescript
// src/websocket/event-handlers.ts
import { Socket } from 'socket.io';
import { RoomManager } from './room-manager';
import { AnalysisEvents } from '../types/events';
import { logger } from '../utils/logger';
import { metrics } from '../monitoring/metrics';

export class EventHandlers {
  constructor(
    private io: any,
    private roomManager: RoomManager
  ) {}

  handleAnalysisStarted(data: AnalysisEvents['analysis:started']): void {
    // Notify all users in the project
    this.roomManager.broadcastToProject(data.projectId, 'analysis:started', {
      ...data,
      timestamp: new Date(),
    });

    // Notify the specific user who initiated the analysis
    this.roomManager.broadcastToUser(data.userId, 'analysis:started', {
      ...data,
      timestamp: new Date(),
      message: `Analysis started for project ${data.projectId}`,
    });

    metrics.analysisEvents.labels('started').inc();
    logger.info(`Analysis started: ${data.analysisId} in project ${data.projectId}`);
  }

  handleAnalysisProgress(data: AnalysisEvents['analysis:progress']): void {
    // Real-time progress updates to project members
    this.roomManager.broadcastToProject(data.projectId, 'analysis:progress', {
      ...data,
      timestamp: new Date(),
    });

    metrics.analysisEvents.labels('progress').inc();
  }

  handleToolCompleted(data: AnalysisEvents['analysis:tool_completed']): void {
    // Notify project members of tool completion
    this.roomManager.broadcastToProject(data.projectId, 'analysis:tool_completed', {
      ...data,
      timestamp: new Date(),
    });

    // Log tool performance metrics
    metrics.toolCompletionDuration.labels(data.toolName).observe(data.duration);
    metrics.toolFindings.labels(data.toolName).inc(data.findingsCount);

    logger.info(`Tool ${data.toolName} completed for analysis ${data.analysisId}: ${data.status}`);
  }

  handleAnalysisCompleted(data: AnalysisEvents['analysis:completed']): void {
    // Comprehensive completion notification
    this.roomManager.broadcastToProject(data.projectId, 'analysis:completed', {
      ...data,
      timestamp: new Date(),
    });

    // Send detailed notification to project owner/admin
    this.roomManager.broadcastToProject(data.projectId, 'system:notification', {
      type: data.status === 'success' ? 'success' : 'error',
      message: `Analysis ${data.status} for project ${data.projectId}`,
      projectId: data.projectId,
      autoClose: false,
      details: {
        duration: data.duration,
        findingsCount: data.findingSummary.total,
        severityBreakdown: data.findingSummary,
      },
    });

    metrics.analysisEvents.labels('completed').inc();
    metrics.analysisDuration.observe(data.duration);
    logger.info(`Analysis completed: ${data.analysisId} (${data.status})`);
  }

  handleNewFinding(data: AnalysisEvents['finding:new']): void {
    // Immediate notification for high-severity findings
    if (['critical', 'high'].includes(data.severity)) {
      this.roomManager.broadcastToProject(data.projectId, 'finding:new', {
        ...data,
        timestamp: new Date(),
        urgent: true,
      });

      // Send system notification for critical findings
      if (data.severity === 'critical') {
        this.roomManager.broadcastToProject(data.projectId, 'system:notification', {
          type: 'error',
          message: `Critical security finding detected: ${data.title}`,
          projectId: data.projectId,
          autoClose: false,
        });
      }
    } else {
      // Non-urgent findings get batched updates
      this.roomManager.broadcastToProject(data.projectId, 'finding:new', {
        ...data,
        timestamp: new Date(),
        urgent: false,
      });
    }

    metrics.findingEvents.labels(data.severity).inc();
    logger.info(`New ${data.severity} finding: ${data.findingId} in project ${data.projectId}`);
  }

  handleFindingUpdated(data: AnalysisEvents['finding:updated']): void {
    this.roomManager.broadcastToProject(data.projectId, 'finding:updated', {
      ...data,
      timestamp: new Date(),
    });

    // Notify assigned user if applicable
    if (data.assignedTo) {
      this.roomManager.broadcastToUser(data.assignedTo, 'finding:assigned', {
        findingId: data.findingId,
        projectId: data.projectId,
        assignedBy: data.updatedBy,
        timestamp: new Date(),
      });
    }

    metrics.findingEvents.labels('updated').inc();
  }

  handlePresenceUpdate(socket: Socket, status: 'online' | 'away'): void {
    const userId = socket.data.user.id;
    const projects = this.roomManager.getProjectsForUser(userId);

    // Broadcast presence to all projects the user is part of
    projects.forEach(projectId => {
      this.roomManager.broadcastToProject(projectId, 'user:presence', {
        userId,
        status,
        projectId,
        timestamp: new Date(),
      });
    });

    logger.debug(`User ${userId} presence updated: ${status}`);
  }

  handleDisconnection(socket: Socket): void {
    const userId = socket.data.user?.id;
    if (!userId) return;

    const projects = this.roomManager.getProjectsForUser(userId);

    // Mark user as offline in all projects
    projects.forEach(projectId => {
      this.roomManager.broadcastToProject(projectId, 'user:presence', {
        userId,
        status: 'offline',
        projectId,
        timestamp: new Date(),
      });
    });

    metrics.disconnectionEvents.inc();
  }

  sendSystemNotification(
    userId: string,
    type: 'info' | 'warning' | 'error' | 'success',
    message: string,
    options: { autoClose?: boolean; duration?: number; projectId?: string } = {}
  ): void {
    const notification: AnalysisEvents['system:notification'] = {
      type,
      message,
      userId,
      projectId: options.projectId,
      autoClose: options.autoClose ?? true,
      duration: options.duration ?? 5000,
    };

    this.roomManager.broadcastToUser(userId, 'system:notification', notification);
    metrics.systemNotifications.labels(type).inc();
  }
}
```

## Authentication and Security

### JWT Authentication Middleware
```typescript
// src/middleware/auth.ts
import jwt from 'jsonwebtoken';
import { Socket } from 'socket.io';
import { logger } from '../utils/logger';

export interface AuthenticatedSocket extends Socket {
  data: {
    user: {
      id: string;
      email: string;
      roles: string[];
    };
  };
}

export class AuthMiddleware {
  static async authenticate(socket: Socket, next: (err?: Error) => void): Promise<void> {
    try {
      const token = this.extractToken(socket);

      if (!token) {
        return next(new Error('Authentication token required'));
      }

      const decoded = await this.verifyToken(token);
      socket.data.user = {
        id: decoded.sub,
        email: decoded.email,
        roles: decoded.roles || [],
      };

      logger.debug(`WebSocket authentication successful for user: ${decoded.sub}`);
      next();
    } catch (error) {
      logger.warn('WebSocket authentication failed:', error);
      next(new Error('Invalid authentication token'));
    }
  }

  private static extractToken(socket: Socket): string | null {
    // Try multiple token sources
    return (
      socket.handshake.auth.token ||
      socket.handshake.headers.authorization?.replace('Bearer ', '') ||
      socket.handshake.query.token as string ||
      null
    );
  }

  private static async verifyToken(token: string): Promise<any> {
    return new Promise((resolve, reject) => {
      jwt.verify(token, process.env.JWT_SECRET!, (err, decoded) => {
        if (err) {
          reject(err);
        } else {
          resolve(decoded);
        }
      });
    });
  }

  static requireRole(requiredRole: string) {
    return (socket: AuthenticatedSocket, next: (err?: Error) => void) => {
      const userRoles = socket.data.user.roles;

      if (!userRoles.includes(requiredRole) && !userRoles.includes('admin')) {
        return next(new Error(`Insufficient permissions. Required role: ${requiredRole}`));
      }

      next();
    };
  }

  static requireProjectAccess(projectId: string) {
    return async (socket: AuthenticatedSocket, next: (err?: Error) => void) => {
      try {
        // Verify user has access to the project
        const hasAccess = await this.checkProjectAccess(socket.data.user.id, projectId);

        if (!hasAccess) {
          return next(new Error(`Access denied to project: ${projectId}`));
        }

        next();
      } catch (error) {
        logger.error('Project access check failed:', error);
        next(new Error('Failed to verify project access'));
      }
    };
  }

  private static async checkProjectAccess(userId: string, projectId: string): Promise<boolean> {
    // Implementation would check database for user's project access
    // For now, return true - this should integrate with the data service
    return true;
  }
}
```

## Performance Monitoring and Metrics

### Prometheus Metrics Integration
```typescript
// src/monitoring/metrics.ts
import { register, Counter, Gauge, Histogram } from 'prom-client';

export const metrics = {
  activeConnections: new Gauge({
    name: 'websocket_active_connections',
    help: 'Number of active WebSocket connections',
  }),

  connectedUsers: new Gauge({
    name: 'websocket_connected_users',
    help: 'Number of unique connected users',
  }),

  connectionEvents: new Counter({
    name: 'websocket_connection_events_total',
    help: 'Total number of connection events',
    labelNames: ['type'], // connect, disconnect
  }),

  messagesSent: new Counter({
    name: 'websocket_messages_sent_total',
    help: 'Total number of messages sent',
    labelNames: ['event_type'],
  }),

  messagesReceived: new Counter({
    name: 'websocket_messages_received_total',
    help: 'Total number of messages received',
    labelNames: ['event_type'],
  }),

  messageLatency: new Histogram({
    name: 'websocket_message_latency_seconds',
    help: 'Message delivery latency',
    buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
  }),

  analysisEvents: new Counter({
    name: 'analysis_events_total',
    help: 'Total number of analysis events',
    labelNames: ['type'], // started, progress, completed
  }),

  findingEvents: new Counter({
    name: 'finding_events_total',
    help: 'Total number of finding events',
    labelNames: ['severity'],
  }),

  systemNotifications: new Counter({
    name: 'system_notifications_total',
    help: 'Total number of system notifications',
    labelNames: ['type'], // info, warning, error, success
  }),

  analysisDuration: new Histogram({
    name: 'analysis_duration_seconds',
    help: 'Analysis completion duration',
    buckets: [1, 5, 10, 30, 60, 300, 600, 1800, 3600],
  }),

  toolCompletionDuration: new Histogram({
    name: 'tool_completion_duration_seconds',
    help: 'Individual tool completion duration',
    labelNames: ['tool'],
    buckets: [1, 5, 10, 30, 60, 300, 600],
  }),

  toolFindings: new Counter({
    name: 'tool_findings_total',
    help: 'Total findings discovered by tool',
    labelNames: ['tool'],
  }),

  disconnectionEvents: new Counter({
    name: 'websocket_disconnection_events_total',
    help: 'Total number of disconnection events',
  }),

  roomOperations: new Counter({
    name: 'websocket_room_operations_total',
    help: 'Total number of room operations',
    labelNames: ['operation'], // join, leave
  }),
};

// Register all metrics
Object.values(metrics).forEach(metric => {
  register.registerMetric(metric);
});
```

## High-Performance Message Queue Integration

### Redis Queue for Event Processing
```typescript
// src/queue/redis-queue.ts
import { Queue, Worker, Job } from 'bullmq';
import { Redis } from 'ioredis';
import { WebSocketServer } from '../websocket/server';
import { logger } from '../utils/logger';

export interface QueueMessage {
  type: string;
  data: any;
  userId?: string;
  projectId?: string;
  priority?: number;
}

export class NotificationQueue {
  private queue: Queue;
  private worker: Worker;
  private redis: Redis;

  constructor(private webSocketServer: WebSocketServer, redisUrl: string) {
    this.redis = new Redis(redisUrl, {
      maxRetriesPerRequest: 3,
      retryDelayOnFailover: 100,
    });

    this.queue = new Queue('notifications', {
      connection: this.redis,
      defaultJobOptions: {
        removeOnComplete: 100,
        removeOnFail: 50,
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 2000,
        },
      },
    });

    this.setupWorker();
  }

  private setupWorker(): void {
    this.worker = new Worker(
      'notifications',
      async (job: Job<QueueMessage>) => {
        await this.processMessage(job.data);
      },
      {
        connection: this.redis,
        concurrency: 10,
        stalledInterval: 30000,
        maxStalledCount: 1,
      }
    );

    this.worker.on('completed', (job) => {
      logger.debug(`Notification job completed: ${job.id}`);
    });

    this.worker.on('failed', (job, err) => {
      logger.error(`Notification job failed: ${job?.id}`, err);
    });

    this.worker.on('stalled', (jobId) => {
      logger.warn(`Notification job stalled: ${jobId}`);
    });
  }

  async addMessage(message: QueueMessage, options?: { delay?: number; priority?: number }): Promise<void> {
    await this.queue.add(
      'notification',
      message,
      {
        priority: options?.priority || message.priority || 0,
        delay: options?.delay,
      }
    );
  }

  private async processMessage(message: QueueMessage): Promise<void> {
    const { type, data, userId, projectId } = message;

    try {
      const io = this.webSocketServer.getIO();

      switch (type) {
        case 'analysis:started':
        case 'analysis:progress':
        case 'analysis:completed':
        case 'analysis:tool_completed':
          if (projectId) {
            io.to(`project:${projectId}`).emit(type, { ...data, timestamp: new Date() });
          }
          break;

        case 'finding:new':
        case 'finding:updated':
          if (projectId) {
            io.to(`project:${projectId}`).emit(type, { ...data, timestamp: new Date() });
          }
          break;

        case 'system:notification':
          if (userId) {
            io.to(`user:${userId}`).emit(type, { ...data, timestamp: new Date() });
          } else if (projectId) {
            io.to(`project:${projectId}`).emit(type, { ...data, timestamp: new Date() });
          } else {
            io.emit(type, { ...data, timestamp: new Date() });
          }
          break;

        default:
          logger.warn(`Unknown message type: ${type}`);
      }

      metrics.messagesSent.labels(type).inc();
    } catch (error) {
      logger.error(`Failed to process message: ${type}`, error);
      throw error;
    }
  }

  async getQueueStats(): Promise<{
    waiting: number;
    active: number;
    completed: number;
    failed: number;
  }> {
    return {
      waiting: await this.queue.getWaiting().then(jobs => jobs.length),
      active: await this.queue.getActive().then(jobs => jobs.length),
      completed: await this.queue.getCompleted().then(jobs => jobs.length),
      failed: await this.queue.getFailed().then(jobs => jobs.length),
    };
  }

  async close(): Promise<void> {
    await this.worker.close();
    await this.queue.close();
    await this.redis.quit();
  }
}
```

## API Endpoints for Notification Management

### HTTP API for External Integration
```typescript
// src/api/router.ts
import express from 'express';
import { WebSocketServer } from '../websocket/server';
import { NotificationQueue } from '../queue/redis-queue';
import { AuthMiddleware } from '../middleware/auth';
import { validateRequest } from '../middleware/validation';
import { NotificationSchemas } from './schemas';

export function createNotificationRouter(
  webSocketServer: WebSocketServer,
  notificationQueue: NotificationQueue
): express.Router {
  const router = express.Router();

  // Send real-time notification
  router.post('/notify',
    AuthMiddleware.authenticate,
    validateRequest(NotificationSchemas.SendNotification),
    async (req, res) => {
      try {
        const { type, data, userId, projectId, priority } = req.body;

        await notificationQueue.addMessage({
          type,
          data,
          userId,
          projectId,
          priority,
        });

        res.json({ success: true, message: 'Notification queued' });
      } catch (error) {
        logger.error('Failed to send notification:', error);
        res.status(500).json({ error: 'Failed to send notification' });
      }
    }
  );

  // Get connection statistics
  router.get('/stats',
    AuthMiddleware.authenticate,
    AuthMiddleware.requireRole('admin'),
    async (req, res) => {
      try {
        const connectionStats = webSocketServer.getConnectionManager().getConnectionStats();
        const queueStats = await notificationQueue.getQueueStats();

        res.json({
          connections: connectionStats,
          queue: queueStats,
          timestamp: new Date(),
        });
      } catch (error) {
        logger.error('Failed to get stats:', error);
        res.status(500).json({ error: 'Failed to get statistics' });
      }
    }
  );

  // Health check endpoint
  router.get('/health', async (req, res) => {
    try {
      const stats = webSocketServer.getConnectionManager().getConnectionStats();
      const queueStats = await notificationQueue.getQueueStats();

      res.json({
        status: 'healthy',
        connections: stats.totalConnections,
        users: stats.totalUsers,
        queueHealth: queueStats.failed < 10 ? 'healthy' : 'degraded',
        timestamp: new Date(),
      });
    } catch (error) {
      res.status(500).json({
        status: 'unhealthy',
        error: error.message,
        timestamp: new Date(),
      });
    }
  });

  return router;
}
```

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Project Structure
```
src/
├── websocket/
│   ├── server.ts              # Main WebSocket server
│   ├── connection-manager.ts  # Connection tracking
│   ├── room-manager.ts        # Room management
│   ├── event-handlers.ts      # Business logic handlers
│   └── middleware/
│       └── auth.ts            # Authentication middleware
├── queue/
│   ├── redis-queue.ts         # Message queue implementation
│   └── job-processor.ts       # Background job processing
├── api/
│   ├── router.ts              # HTTP API endpoints
│   ├── schemas.ts             # Request/response schemas
│   └── middleware/
│       ├── auth.ts            # HTTP authentication
│       ├── validation.ts      # Request validation
│       └── rate-limit.ts      # Rate limiting
├── types/
│   ├── events.ts              # Event type definitions
│   └── user.ts                # User type definitions
├── monitoring/
│   ├── metrics.ts             # Prometheus metrics
│   └── health-check.ts        # Health monitoring
├── utils/
│   ├── logger.ts              # Structured logging
│   └── config.ts              # Configuration management
└── app.ts                     # Application entry point
```

### Features Implemented
- ✅ High-performance Socket.IO server with Redis adapter
- ✅ JWT-based authentication for WebSocket connections
- ✅ Room management for user and project-specific notifications
- ✅ Real-time analysis progress and finding updates
- ✅ Message queue integration for reliable delivery
- ✅ Comprehensive metrics and monitoring
- ✅ Connection management with automatic cleanup
- ✅ HTTP API for external notification triggers
- ✅ Scalability support for multiple server instances

## Acceptance Criteria

### Real-Time Performance
- [ ] WebSocket connections support 1000+ concurrent users
- [ ] Message delivery latency under 100ms
- [ ] Automatic reconnection with exponential backoff
- [ ] Memory usage optimized for long-running connections

### Functionality
- [ ] Real-time analysis progress updates delivered successfully
- [ ] Finding notifications triggered immediately for critical issues
- [ ] User presence tracking functional across projects
- [ ] Room management handles user project membership correctly

### Reliability
- [ ] Message queue ensures no lost notifications during outages
- [ ] Connection failures handled gracefully with recovery
- [ ] Authentication properly validates all WebSocket connections
- [ ] Rate limiting prevents abuse and resource exhaustion

### Monitoring
- [ ] Prometheus metrics available for all connection and message events
- [ ] Health checks validate WebSocket server and queue health
- [ ] Connection statistics provide operational visibility
- [ ] Error logging captures all failure scenarios for debugging

This WebSocket implementation provides a robust foundation for real-time communication across the Solidity Security Platform with enterprise-grade performance and reliability.