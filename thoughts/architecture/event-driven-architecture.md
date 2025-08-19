# Event-Driven Architecture

## Overview

The Financial Forecasting Engine employs a single-instance, in-memory event-driven architecture to enable instant updates, maintain audit trails, and organize internal components. Events represent state changes in the domain and trigger in-process handlers synchronously within the same runtime. The system uses the Bus infrastructure for type-safe event handling with Zod schema validation.

## Core Concepts

### Event Processing Model
- Events are immutable facts about state changes
- Synchronous processing ensures consistency
- Single-player system with request-level mutex
- Events handled immediately via Promise.all()

### CQRS Pattern
- Commands modify state and emit events
- Queries read from in-memory projections
- Event handlers update read models instantly
- Immediate consistency within single process

### In-Process Pub-Sub
- Publishers emit events via `Bus.publish()`
- Subscribers register handlers via `Bus.subscribe()`
- All handlers execute in same process
- Wildcard subscriptions via "*" for logging

### Future Scope
- Event persistence and replay
- Asynchronous event processing
- Event sourcing for recovery
- Complex ordering guarantees

## Bus System Implementation

### Core Bus API
```typescript
export namespace Bus {
  // Define a typed event with Zod schema
  export function event<T extends z.ZodType>(
    type: string,
    schema: T
  ): EventDefinition<z.infer<T>>
  
  // Publish event to all subscribers
  export async function publish<T>(
    def: EventDefinition<T>,
    properties: T
  ): Promise<void>
  
  // Subscribe to specific event or all events ("*")
  export function subscribe<T>(
    def: EventDefinition<T> | "*",
    callback: (event: { type: string; properties: T }) => void
  ): Subscription
}
```

### Event Definition Pattern
```typescript
export namespace Account {
  export const Event = {
    created: Bus.event("account.created", Account.Info),
    updated: Bus.event("account.updated", Account.Info),
    balanceChanged: Bus.event("account.balance.changed", z.object({
      accountId: z.string(),
      oldBalance: z.number(),
      newBalance: z.number()
    }))
  }
}
```

### Event Dispatch Mechanism
- Synchronous dispatch via Promise.all()
- All handlers execute immediately
- No priority system (all handlers equal)
- Simple error propagation

### Subscription Management
- Type-safe event subscriptions via Zod
- Wildcard "*" for audit/logging
- Subscriptions stored in App.state()
- Automatic cleanup on shutdown

## Event Types with Zod Schemas

### Account Events
```typescript
export namespace Account {
  export const Event = {
    created: Bus.event("account.created", Account.Info),
    updated: Bus.event("account.updated", z.object({
      old: Account.Info,
      new: Account.Info
    })),
    balanceChanged: Bus.event("account.balance.changed", z.object({
      accountId: z.string().uuid(),
      oldBalance: z.number(),
      newBalance: z.number(),
      trigger: z.enum(["transfer", "adjustment", "recalculation"])
    })),
    statusChanged: Bus.event("account.status.changed", z.object({
      accountId: z.string().uuid(),
      oldStatus: z.enum(["active", "frozen", "closed"]),
      newStatus: z.enum(["active", "frozen", "closed"])
    }))
  }
}
```

### Transfer Events
```typescript
export namespace Transfer {
  export const Event = {
    created: Bus.event("transfer.created", Transfer.Info),
    stateChanged: Bus.event("transfer.state.changed", z.object({
      transferId: z.string().uuid(),
      oldStatus: z.enum(["projected", "pending", "posted"]),
      newStatus: z.enum(["projected", "pending", "posted"]),
      reason: z.string().optional()
    })),
    posted: Bus.event("transfer.posted", z.object({
      transfer: Transfer.Info,
      postedAt: z.date()
    })),
    rejected: Bus.event("transfer.rejected", z.object({
      transferId: z.string().uuid(),
      reason: z.string()
    }))
  }
}
```

### Schedule Events
```typescript
export namespace Schedule {
  export const Event = {
    created: Bus.event("schedule.created", Schedule.Info),
    modified: Bus.event("schedule.modified", z.object({
      old: Schedule.Info,
      new: Schedule.Info,
      affectedTransferIds: z.array(z.string().uuid())
    })),
    triggered: Bus.event("schedule.triggered", z.object({
      scheduleId: z.string().uuid(),
      generatedTransferIds: z.array(z.string().uuid()),
      nextGenerationDate: z.date()
    })),
    paused: Bus.event("schedule.paused", z.object({
      scheduleId: z.string().uuid(),
      pausedUntil: z.date().optional()
    }))
  }
}
```

### System Events (Future Scope)
System-level events for maintenance, notifications, and error handling will be implemented in future development cycles.

## Event Processing Patterns

### Current Implementation
All events are processed synchronously via Bus.publish():
- Handlers execute immediately via Promise.all()
- Ensures consistency in single-player system
- Simple error handling and propagation
- No complex ordering requirements

### Future Enhancements
- Asynchronous processing for heavy operations
- Event replay capabilities
- Event persistence for recovery
- Priority-based handler execution

## Handler Implementation

### Subscription Pattern
```typescript
// Subscribe to specific event
Bus.subscribe(Account.Event.created, async (event) => {
  log.info("Account created", { accountId: event.properties.id })
  // Handle account creation
})

// Subscribe to all events for audit
Bus.subscribe("*", async (event) => {
  log.debug("Event occurred", { type: event.type, properties: event.properties })
})
```

### Handler Examples

**Balance Update Handler**
```typescript
Bus.subscribe(Transfer.Event.posted, async (event) => {
  const transfer = event.properties.transfer
  
  // Update source account balance
  const sourceBalance = Account.calculateBalance(transfer.fromAccountId)
  await Bus.publish(Account.Event.balanceChanged, {
    accountId: transfer.fromAccountId,
    oldBalance: sourceBalance + transfer.amount,
    newBalance: sourceBalance,
    trigger: "transfer"
  })
  
  // Update destination account balance
  const destBalance = Account.calculateBalance(transfer.toAccountId)
  await Bus.publish(Account.Event.balanceChanged, {
    accountId: transfer.toAccountId,
    oldBalance: destBalance - transfer.amount,
    newBalance: destBalance,
    trigger: "transfer"
  })
})
```

### Handler Categories

**State Handlers**
- Update in-memory state via App.state()
- Maintain consistency rules
- Trigger cascading events

**Projection Handlers**
- Update in-memory read models
- Maintain query projections
- Calculate derived values instantly

**Audit Handlers**
- Log all events via wildcard subscription
- Track state changes
- Simple console or file logging

**Integration Handlers (Future Scope)**
- External system communication
- Notification delivery
- Third-party service updates

## Event Stream Management

### Current Implementation
- Events processed immediately on publish
- No event storage or history
- Handlers execute via Promise.all()
- Simple in-memory state updates

### Future Enhancements
- Event persistence for recovery
- Event replay capabilities
- Stream analytics and aggregations
- Time-windowed computations

## Client Event Delivery (Future Scope)

Real-time event delivery to clients via Server-Sent Events (SSE) or WebSockets will be implemented in future development cycles. Current implementation relies on polling or request-response patterns.

## Error Handling

### Current Implementation
- Simple error propagation from handlers
- Errors logged via Log system
- Failed handlers don't stop other handlers
- Manual intervention for recovery

### Future Enhancements
- Retry mechanisms
- Dead letter queues
- Circuit breakers
- Automated recovery procedures

## Performance Considerations

### Current Implementation
- Synchronous processing is sufficient for single-player system
- Small data sets don't require optimization
- Direct memory access ensures fast processing
- No complex performance requirements

### Future Optimizations
- Event batching for high throughput
- Performance monitoring metrics
- Memory usage optimization
- Handler execution profiling

## Testing Strategies

### Unit Testing
```typescript
import { describe, it, expect } from "bun:test"

describe("Account Events", () => {
  it("should emit created event", async () => {
    const events: any[] = []
    Bus.subscribe("*", (event) => events.push(event))
    
    const account = Account.create({ name: "Test", type: "cash" })
    
    expect(events).toHaveLength(1)
    expect(events[0].type).toBe("account.created")
  })
})
```

### Integration Testing
- End-to-end event flows
- Handler chain verification
- State consistency checks

## Schema Evolution

### Zod Schema Versioning
- Use `.extend()` for backward-compatible changes
- Add optional fields for new features
- Deprecate fields gradually
- Version events if breaking changes needed

### Example Evolution
```typescript
// Version 1
const AccountV1 = z.object({
  id: z.string(),
  name: z.string()
})

// Version 2 - backward compatible
const AccountV2 = AccountV1.extend({
  metadata: z.object({}).optional() // New optional field
})
```