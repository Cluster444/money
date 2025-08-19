# Architecture Documentation Overview

## Purpose
This directory contains comprehensive technical design documentation for the Financial Forecasting Engine - a single-instance, in-memory financial calculation system for forecasting account balances, tracking credit utilization, and managing cash flow through double-entry accounting principles.

## Documentation Structure

### Reading Order
The documentation is organized to build understanding progressively. Follow this recommended reading sequence:

**Note**: The core-systems.md document provides detailed implementation patterns for infrastructure components and is referenced throughout other documents.

1. **system-architecture.md**
   - *Synopsis*: High-level system overview and architectural principles
   - *Key Topics*: Component layout, data flow patterns, deployment architecture, system boundaries
   - *Read First*: Provides the foundation for understanding how all pieces fit together

2. **domain-model.md**
   - *Synopsis*: Core business entities, relationships, and rules
   - *Key Topics*: Account types, Transfer states, Schedule definitions, business invariants
   - *Read Second*: Essential for understanding what the system manages and how business logic operates

3. **event-driven-architecture.md**
   - *Synopsis*: In-process event handling and instant update mechanisms
   - *Key Topics*: In-memory event bus, domain events, event handlers, SSE streaming
   - *Read Third*: Explains how the single instance manages events and updates

4. **api-design.md**
   - *Synopsis*: HTTP interface with stateful server and instant streaming
   - *Key Topics*: REST endpoints, SSE streaming, in-memory responses, validation
   - *Read Fourth*: Details the single-instance API server

5. **testing-strategy.md**
   - *Synopsis*: Comprehensive testing approach without mocks
   - *Key Topics*: Test patterns, state isolation, event verification, performance testing
   - *Read for Testing*: Essential for understanding how to test the in-memory system

6. **development-workflow.md**
   - *Synopsis*: Development environment, tools, and deployment
   - *Key Topics*: Monorepo setup, Bun/TypeScript configuration, testing, simple deployment
   - *Read Last*: Practical guide for development and single-instance deployment

## Quick Reference

### Core Concepts
- **Single-Instance Design**: Stateful, in-memory operation for maximum performance
- **Double-Entry Accounting**: Balances computed from debits/credits, not stored
- **Transfer States**: Projected → Pending → Posted workflow
- **Account Types**: Cash (spendable), Credit (debt), Vendor (external)
- **Daily Granularity**: All financial operations at day-level precision
- **Event-Driven**: Instant updates via in-memory event bus and SSE
- **Transactional Consistency**: Atomic operations with automatic rollback on failure

### Technical Stack
- **Runtime**: Bun (TypeScript execution and testing)
- **Monorepo**: Turborepo for build orchestration
- **Code Quality**: Biome for formatting/linting
- **Architecture**: Single-instance, event-driven with CQRS patterns
- **API**: Stateful REST server with Server-Sent Events
- **Storage**: In-memory with optional persistence

### Key Design Decisions
- Single-instance, stateful architecture
- Pure in-memory operation with optional snapshots
- Headless core with built-in web interface
- Event sourcing for audit trails
- Computed balances over stored values
- Schedule-based transfer generation
- Simple deployment with acceptable downtime

## Navigation Guide

### For Different Roles

**System Architects**
- Start with `system-architecture.md`
- Focus on `event-driven-architecture.md`
- Review integration points in `api-design.md`

**Domain Experts**
- Begin with `domain-model.md`
- Understand state flows in `event-driven-architecture.md`
- Review business endpoints in `api-design.md`

**Developers**
- Quick scan of `system-architecture.md`
- Deep dive into `domain-model.md`
- Set up environment with `development-workflow.md`
- Implement against `api-design.md`

**Frontend Engineers**
- Start with `api-design.md`
- Understand events in `event-driven-architecture.md`
- Review domain concepts in `domain-model.md`

## Document Relationships

```
system-architecture.md
    ├── Defines overall structure
    ├── References domain concepts → domain-model.md
    ├── Describes event flow → event-driven-architecture.md
    └── Mentions API layer → api-design.md

domain-model.md
    ├── Defines entities used by → event-driven-architecture.md
    ├── Shapes API resources in → api-design.md
    └── Implemented using tools from → development-workflow.md

event-driven-architecture.md
    ├── Processes domain events from → domain-model.md
    ├── Streams updates via → api-design.md
    └── Built with patterns from → system-architecture.md

api-design.md
    ├── Exposes domain operations from → domain-model.md
    ├── Streams events defined in → event-driven-architecture.md
    └── Deployed as described in → system-architecture.md

development-workflow.md
    └── Supports implementation of all above
```

## Future Documentation
As the system evolves, additional documentation may include:
- Persistence layer design
- User interface specifications
- Security and authentication details
- Deployment and operations guide
- Performance optimization strategies
- Migration and upgrade procedures