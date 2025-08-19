# System Architecture

## Overview

The Financial Forecasting Engine is a TypeScript-based application designed to forecast projected account balances, track credit utilization, and monitor cash availability. The system operates as a single-instance, in-memory financial calculation engine with an event-driven core, designed for single-player use with request-level consistency guarantees.

## Architecture Principles

- **Single-Instance Design**: Stateful, in-memory operation for maximum performance
- **Namespace Architecture**: Core systems and business logic organized as TypeScript namespaces
- **Domain-Driven Design**: Core business logic encapsulated in domain models
- **Event-Driven Architecture**: Synchronous in-process event bus for state changes
- **Type-Safe Validation**: Zod schemas for runtime validation and TypeScript types
- **Headless Core**: Business logic separated from presentation layer
- **Daily Granularity**: Financial operations work at day-level precision to avoid timezone complexity
- **Memory-First**: All data operations happen in memory (persistence is future scope)
- **Single-Player System**: Request-level mutex ensures consistency for single user

## Core Infrastructure Systems

The application is built on a foundation of core infrastructure systems, each implemented as a namespace in `src/system/index.ts`:

### App System
Orchestrates application lifecycle and service management:
- `App.state()`: Creates singleton services with initialization/shutdown lifecycle
- `App.provide()`: Establishes application context for operations
- Service registry tracking and dependency management
- Graceful startup and shutdown coordination

### Context System
Provides request-scoped context using AsyncLocalStorage:
- Thread-local-like storage for async operations
- Request context flows through entire operation chain
- No explicit context passing required
- Isolation between concurrent operations

### Log System
Structured logging with service isolation:
- Each namespace creates its own logger: `Log.create({ service: "name" })`
- Level-based filtering (DEBUG, INFO, WARN, ERROR)
- Tagged logging for tracing through systems
- Timing utilities for performance monitoring

### Bus System
Synchronous event bus for inter-system communication:
- `Bus.event()`: Defines typed events with Zod schemas
- `Bus.publish()`: Emits events to all subscribers (returns Promise.all)
- `Bus.subscribe()`: Registers handlers for specific or wildcard events
- Type-safe event payloads with automatic validation
- OpenAPI schema generation from event definitions

### Config System
Configuration management with validation:
- Loads configuration from multiple sources
- Zod schema validation for all configuration
- Hierarchical configuration with deep merging
- Lazy loading with validation on access

### Global System
Foundation layer providing standardized paths:
- XDG base directory specification compliance
- Application-specific directories (data, log, cache, config, state)
- No behavior, pure configuration
- Used by all other systems for file operations

## Business Domain Systems

Built on top of core infrastructure, organized as namespaces:

### Account System
Account management namespace:
- Account types: Cash, Credit, Vendor
- Balance calculation from transfer history
- Event emission for state changes
- Zod schemas for validation

### Transfer System
Money movement between accounts:
- State machine: Projected → Pending → Posted
- Double-entry accounting enforcement
- Validation and business rules
- Event-driven state transitions

### Schedule System
Recurring transaction management:
- Recurrence rule engine
- Transfer generation logic
- Horizon-based projection planning
- Schedule modification handling

## Data Flow Architecture

### Request Processing Flow
1. Client sends HTTP request to the single instance
2. Core validates and processes request in-memory
3. Immediate response returned from memory state
4. Events emitted for state changes
5. In-process handlers update projections
6. Updates instantly streamed to all connected clients via SSE

### Event Processing Flow
1. Domain action triggers event emission via `Bus.publish()`
2. In-memory event bus notifies registered handlers synchronously
3. All handlers execute via `Promise.all()` for consistent ordering
4. Secondary events may be emitted
5. Updates available for client polling (SSE is future scope)

### Transfer State Transitions
```
Projected -> (User Queue) -> Pending -> Posted
            |                    |
            +-> Rejected         +-> Modified
```

## Namespace Architecture Pattern

Each system follows a consistent pattern defined in `src/system/index.ts`:

```typescript
export namespace SomeSystem {
  const log = Log.create({ service: "some-system" })
  
  // State management via App.state
  const state = App.state("some-system", () => ({
    // Initialize state
  }))
  
  // Zod schemas for validation
  export const Info = z.object({
    // Schema definition
  }).openapi({ ref: "SomeSystem" })
  export type Info = z.infer<typeof Info>
  
  // Event definitions (optional)
  export const Event = {
    action: Bus.event("system.action", z.object({ /* payload */ }))
  }
  
  // Business operations
  export function operation(): void {
    // Implementation
  }
}
```

## Deployment Architecture

### Development Environment
- Bun runtime for TypeScript execution
- Zod for runtime validation and type generation
- Biome for code formatting/linting
- Pure in-memory operation

### Production Deployment
- Single server instance
- Simple process management (systemd/pm2)
- In-memory state only (persistence is future scope)
- Acceptable brief downtime for deployments
- Single-player system simplifies deployment

## Security Architecture

### Current Implementation
- Zod schema validation for all inputs
- Type-safe operations throughout
- Single-player system reduces attack surface

### Future Scope
- API authentication and authorization
- Role-based permissions
- Encryption at rest when persistence is added
- HTTPS for secure communication
- Audit logging for compliance

## Future Considerations

The following areas are identified for future development cycles:

### Persistence Layer
- State serialization to disk
- Event sourcing for recovery
- Backup and restore capabilities
- Transaction log for audit

### Multi-User Support
- User authentication and sessions
- Account-level access control
- Concurrent operation handling
- Data isolation between users

### Memory Management
- Efficient data structures for large datasets
- Historical data archival
- Memory usage monitoring
- Garbage collection optimization

### External Integrations
- Banking API connections
- Payment processor webhooks
- Notification services (email/SMS)
- Analytics and reporting tools

### Client Applications
- Web dashboard
- Mobile applications
- Real-time updates via SSE
- Third-party API access

## System Boundaries

### Core Responsibilities
- Business logic execution
- In-memory state management
- Event generation and distribution
- Transaction processing
- Balance calculation and forecasting

### Interface Responsibilities
- Request validation and processing
- Response formatting
- SSE connection management
- Authentication/authorization

### Client Responsibilities
- User interaction handling
- Local UI state management
- Presentation logic
- Connection retry logic
