# Core Infrastructure Systems

## Overview

The Financial Forecasting Engine is built on a foundation of core infrastructure systems that provide essential services like state management, logging, event handling, and configuration. These systems are implemented as TypeScript namespaces and work together to create a cohesive application framework.

## System Architecture Pattern

Each core system follows a consistent namespace pattern:

```typescript
export namespace SystemName {
  // Private logger instance
  const log = Log.create({ service: "system-name" })
  
  // State management (if needed)
  const state = App.state("system-name", () => ({
    // Initialize state
  }))
  
  // Public types and schemas
  export const Schema = z.object({
    // Zod schema definition
  }).openapi({ ref: "SystemName" })
  export type Schema = z.infer<typeof Schema>
  
  // Public functions
  export function operation(): void {
    // Implementation
  }
}
```

## Core Systems

### App System

**Purpose**: Orchestrates application lifecycle, service management, and state persistence.

**Key Components**:
- `App.state(name, init)`: Creates singleton services with lifecycle management
- `App.provide(fn)`: Establishes application context
- Service registry for tracking all registered services
- Initialization and shutdown coordination

**Implementation**:
```typescript
export namespace App {
  // Register a stateful service
  export function state<T>(name: string, init: () => T): () => T {
    // Returns getter function for service state
    // Handles initialization on first access
    // Manages cleanup on shutdown
  }
  
  // Provide application context
  export function provide<T>(fn: () => T): T {
    // Creates application context
    // Manages service lifecycle
    // Handles graceful shutdown
  }
}
```

**Usage Example**:
```typescript
const accountState = App.state("account", () => ({
  accounts: new Map<string, Account.Info>()
}))

// Access state
const accounts = accountState().accounts
```

### Context System

**Purpose**: Provides request-scoped context using AsyncLocalStorage for thread-local-like storage in async operations.

**Key Components**:
- Uses Node.js AsyncLocalStorage API
- Creates isolated contexts per operation
- Automatic context propagation through async calls
- No explicit parameter passing required

**Implementation**:
```typescript
export namespace Context {
  export function create<T>(name: string) {
    const storage = new AsyncLocalStorage<T>()
    
    return {
      use(): T {
        const result = storage.getStore()
        if (!result) throw new NotFound(name)
        return result
      },
      
      provide<R>(value: T, fn: () => R): R {
        return storage.run<R>(value, fn)
      }
    }
  }
}
```

**Usage Example**:
```typescript
const RequestContext = Context.create<{ userId: string }>("request")

// Provide context
RequestContext.provide({ userId: "123" }, () => {
  // Context available in all async operations
  processRequest()
})

// Use context anywhere in call stack
function processRequest() {
  const { userId } = RequestContext.use()
  // userId is available without passing parameters
}
```

### Log System

**Purpose**: Structured logging with service isolation and level-based filtering.

**Key Components**:
- Service-specific loggers via `Log.create()`
- Level filtering (DEBUG, INFO, WARN, ERROR)
- Console or file output modes
- Timing utilities for performance monitoring
- Tagging support for correlation

**Implementation**:
```typescript
export namespace Log {
  export function create(options: { service: string }): Logger {
    return {
      debug(message: any, extra?: Record<string, any>): void { },
      info(message: any, extra?: Record<string, any>): void { },
      warn(message: any, extra?: Record<string, any>): void { },
      error(message: any, extra?: Record<string, any>): void { },
      
      time(message: string, extra?: Record<string, any>) {
        const start = Date.now()
        return {
          stop(): void {
            const duration = Date.now() - start
            this.info(message, { ...extra, duration })
          }
        }
      }
    }
  }
}
```

**Usage Example**:
```typescript
const log = Log.create({ service: "account" })

log.info("Creating account", { accountId: "123" })

const timer = log.time("Balance calculation")
// ... perform calculation
timer.stop() // Logs with duration
```

### Bus System

**Purpose**: Synchronous event bus for inter-system communication with type-safe event definitions.

**Key Components**:
- `Bus.event()`: Defines typed events with Zod schemas
- `Bus.publish()`: Emits events to all subscribers
- `Bus.subscribe()`: Registers event handlers
- Wildcard subscriptions via "*"
- OpenAPI schema generation from events

**Implementation**:
```typescript
export namespace Bus {
  // Define a typed event
  export function event<T extends z.ZodType>(
    type: string,
    schema: T
  ): EventDefinition<z.infer<T>> {
    // Register event type
    // Return typed event definition
  }
  
  // Publish event to subscribers
  export async function publish<T>(
    def: EventDefinition<T>,
    properties: T
  ): Promise<void> {
    // Validate properties with schema
    // Notify all subscribers via Promise.all()
  }
  
  // Subscribe to events
  export function subscribe<T>(
    def: EventDefinition<T> | "*",
    callback: (event: { type: string; properties: T }) => void
  ): Subscription {
    // Register handler
    // Return unsubscribe function
  }
}
```

**Usage Example**:
```typescript
// Define event
const AccountCreated = Bus.event("account.created", z.object({
  id: z.string(),
  name: z.string()
}))

// Subscribe to event
Bus.subscribe(AccountCreated, async (event) => {
  console.log("Account created:", event.properties.id)
})

// Publish event
await Bus.publish(AccountCreated, {
  id: "123",
  name: "Test Account"
})
```

### Transaction System

**Purpose**: Provides atomic operations with optional read isolation for multi-step financial operations, ensuring consistency even when complex operations fail partway through.

**Key Components**:
- Mutation recording that defers all state changes until commit
- Optional read isolation for transaction-local view of data
- Automatic rollback on errors with no partial state changes
- Integration with existing Map/Set state containers via proxies
- Nested transaction support for complex workflows

**Core Concepts**:

The transaction system intercepts all mutations to state Maps and Sets, recording them in a transaction log rather than applying them immediately. When a transaction commits, all mutations are applied atomically. If an error occurs at any point, the transaction is rolled back and no mutations are applied.

**Mutation Recording**:

Each mutation is captured as a structured operation containing:
```typescript
interface Mutation {
  type: 'set' | 'delete' | 'update'
  target: Map<any, any> | Set<any>
  key?: any
  value?: any
  oldValue?: any  // For potential undo operations
}
```

**Read Isolation Modes**:

The system supports two read modes:

1. **Non-isolated (default)**: Reads see the current committed state. This is suitable for most operations where you want to see other transactions' committed changes.

2. **Isolated**: Reads see uncommitted changes within the current transaction but not changes from other concurrent operations. The transaction maintains a read cache that overlays the base state, checking the cache first for any reads.

**State Container Wrapping**:

The transaction system wraps Map and Set instances with Proxy objects that intercept operations. When a Map's `set()` method is called within a transaction context, instead of modifying the Map directly, it records a mutation. The actual Map remains unchanged until commit.

**Transaction Context Flow**:

Transactions leverage the existing Context system to flow transaction state through async operations. When `Transaction.begin()` is called, it creates a transaction context that follows through all subsequent function calls within that transaction's scope.

**Commit Process**:

During commit, the system:
1. Validates the transaction is still active
2. Applies all recorded mutations in order to their target containers
3. Marks the transaction as complete
4. Publishes a transaction committed event via the Bus system

**Rollback Behavior**:

On rollback or error:
1. All recorded mutations are discarded
2. The read cache (if using isolation) is cleared
3. No state changes occur
4. A rollback event is published for audit purposes

**Event Integration**:

Domain events published during a transaction are queued and only actually published after successful commit. This ensures event handlers don't react to changes that might be rolled back.

**Implementation Approach**:

Domain namespaces initialize their state Maps with transaction support:
- Replace `new Map()` with `Transaction.wrapMap(new Map())`
- All existing code continues to work unchanged
- Transaction boundaries are established at operation entry points

**Usage Pattern**:

Transaction boundaries are typically established at the API handler level or for complex multi-step operations. The implementing code creates a transaction, runs the business logic within it, and commits on success or rolls back on failure.

**What This System Does NOT Provide**:

1. **True Concurrency Control**: This is a single-threaded, single-instance system. There are no concurrent transactions in the traditional database sense.

2. **Serializable Isolation**: The system doesn't detect or prevent write skew anomalies that could occur if this were a multi-user system.

3. **Durability**: Transactions are in-memory only. A system crash loses all state including committed transactions.

4. **Distributed Transactions**: This only works within a single process. Cannot coordinate across multiple services.

5. **MVCC or Snapshots**: The system doesn't maintain multiple versions of data for different transaction snapshots.

6. **Deadlock Detection**: Not needed in single-threaded execution, but the system doesn't handle circular waits if they were somehow created.

7. **Transaction Logs for Recovery**: No write-ahead log or transaction history for crash recovery.

**Performance Considerations**:

- Mutation recording has minimal overhead (simple array push)
- Read isolation adds one cache lookup per read operation
- Commit is O(n) where n is the number of mutations
- No locking overhead since execution is single-threaded
- Memory overhead is proportional to transaction size

**Testing Benefits**:

The transaction system greatly simplifies testing by providing automatic cleanup between test cases. Tests can run operations and roll back, leaving no state changes that could affect subsequent tests.

```

### SortedDateMap System

**Purpose**: Provides an efficient sorted map for date-based indexes, crucial for balance projections and time-range queries.

**Key Components**:
- Internal Map for O(1) lookups by date
- Sorted keys array for ordered iteration
- Automatic re-sorting on mutations
- Iterator support for range queries

**Implementation**:
```typescript
export class SortedDateMap<V> {
    private map: Map<Date, V> = new Map();
    private sortedKeys: Date[] = [];

    set(key: Date, value: V): void {
        this.map.set(key, value);
        this.updateSortedKeys();
    }

    get(key: Date): V | undefined {
        return this.map.get(key);
    }

    delete(key: Date): boolean {
        const deleted = this.map.delete(key);
        if (deleted) {
            this.updateSortedKeys();
        }
        return deleted;
    }

    private updateSortedKeys(): void {
        this.sortedKeys = Array.from(this.map.keys()).sort((a, b) => a.getTime() - b.getTime());
    }

    // Example of sorted iteration
    * [Symbol.iterator](): IterableIterator<[Date, V]> {
        for (const key of this.sortedKeys) {
            yield [key, this.map.get(key)!];
        }
    }
    
    // Range query support
    * range(startDate: Date, endDate: Date): IterableIterator<[Date, V]> {
        for (const key of this.sortedKeys) {
            if (key < startDate) continue;
            if (key > endDate) break;
            yield [key, this.map.get(key)!];
        }
    }
    
    size(): number {
        return this.map.size;
    }
    
    clear(): void {
        this.map.clear();
        this.sortedKeys = [];
    }
}
```

**Usage Example**:
```typescript
// In Transfer namespace
const state = App.state("transfer", () => ({
  byAccountAndDate: new Map<string, SortedDateMap<Set<string>>>()
}))

// Efficient balance projection
export function getProjectedBalance(accountId: string, date: Date): Money {
  let balance = getPendingBalance(accountId)
  const accountTransfers = state().byAccountAndDate.get(accountId)
  
  if (!accountTransfers) return balance
  
  // Iterate in date order up to target date
  for (const [transferDate, transferIds] of accountTransfers) {
    if (transferDate > date) break  // Stop at target date
    
    for (const transferId of transferIds) {
      const transfer = getTransfer(transferId)
      if (transfer.status !== 'projected') continue
      
      // Apply transfer to balance
      if (transfer.fromAccountId === accountId) {
        balance -= transfer.amount
      } else {
        balance += transfer.amount
      }
    }
  }
  
  return balance
}
```

**Performance Characteristics**:
- `set()`: O(n log n) due to re-sort, but amortized O(log n) if insertions are ordered
- `get()`: O(1) via internal Map
- `delete()`: O(n log n) due to re-sort
- Iteration: O(n) in sorted order
- Range query: O(k) where k is the number of items in range
- Memory: O(n) for both Map and sorted array

**Design Rationale**:
The dual structure (Map + sorted array) provides the best of both worlds:
- Fast lookups for specific dates
- Efficient ordered iteration for balance calculations
- Simple implementation without complex tree structures
- Sufficient performance for the single-player use case

### Config System

**Purpose**: Configuration management with validation and hierarchical merging.

**Key Components**:
- Loads from multiple sources (files, environment)
- Zod schema validation
- Deep merging of configurations
- Lazy loading with caching
- Type-safe access

**Implementation**:
```typescript
export namespace Config {
  const ConfigSchema = z.object({
    server: z.object({
      port: z.number().default(3000),
      host: z.string().default("localhost")
    }),
    database: z.object({
      url: z.string().optional()
    })
  })
  
  export function load(): z.infer<typeof ConfigSchema> {
    // Load from files and environment
    // Validate with Zod
    // Return typed configuration
  }
}
```

**Usage Example**:
```typescript
const config = Config.load()
console.log(`Server running on ${config.server.host}:${config.server.port}`)
```

### Global System

**Purpose**: Foundation layer providing standardized paths using XDG base directory specification.

**Key Components**:
- XDG compliance for cross-platform support
- Application-specific directory structure
- No behavior, pure configuration
- Used by all systems for file operations

**Implementation**:
```typescript
export namespace Global {
  export const Path = {
    data: path.join(xdgData, "app"),
    bin: path.join(xdgData, "app", "bin"),
    log: path.join(xdgData, "app", "log"),
    cache: path.join(xdgCache, "app"),
    config: path.join(xdgConfig, "app"),
    state: path.join(xdgState, "app")
  } as const
}
```

**Usage Example**:
```typescript
const logFile = path.join(Global.Path.log, "app.log")
const configFile = path.join(Global.Path.config, "settings.json")
```

## System Interactions

### Initialization Flow

```typescript
// 1. App provides context
App.provide(() => {
  // 2. Initialize core systems
  Log.init({ print: true, level: "INFO" })
  Config.load()
  
  // 3. Register domain services
  const accountState = App.state("account", () => ({
    accounts: new Map()
  }))
  
  // 4. Setup event handlers
  Bus.subscribe("*", (event) => {
    log.debug("Event", { type: event.type })
  })
  
  // 5. Start application
  startServer()
})
```

### Request Processing Flow

```typescript
function handleRequest(req: Request, res: Response) {
  // Create request context
  Context.provide({ requestId: req.id }, async () => {
    try {
      // Log request
      log.info("Request received", { path: req.path })
      
      // Process with domain logic
      const result = await processBusinessLogic()
      
      // Emit events
      await Bus.publish(SomeEvent, result)
      
      // Return response
      res.json(result)
    } catch (error) {
      log.error("Request failed", { error })
      res.status(500).json({ error: "Internal error" })
    }
  })
}
```

### Event Flow Example

```typescript
// Account creation flow
async function createAccount(data: AccountData) {
  // 1. Create account in state
  const account = Account.create(data)
  
  // 2. Emit creation event
  await Bus.publish(Account.Event.created, account)
  
  // 3. Handlers react to event
  // - Balance calculator initializes balance
  // - Audit logger records creation
  // - Cache updates indexes
  
  return account
}
```

## Best Practices

### System Design

1. **Single Responsibility**: Each system has one clear purpose
2. **Namespace Isolation**: Systems are self-contained namespaces
3. **Type Safety**: Use Zod for runtime validation
4. **Event-Driven**: Communicate via Bus events
5. **Context Propagation**: Use Context for request scope

### State Management

1. **Use App.state()**: For singleton services
2. **Immutable Updates**: Don't mutate state directly
3. **Event Emission**: Emit events after state changes
4. **Lazy Initialization**: State initialized on first access
5. **Cleanup Handling**: Implement shutdown hooks

### Error Handling

1. **Structured Logging**: Use Log system for all errors
2. **Context Preservation**: Include context in error logs
3. **Event Failures**: Handle event handler failures gracefully
4. **Validation Errors**: Use Zod's error formatting
5. **Recovery Strategies**: Define clear recovery paths

### Testing

1. **Reset State**: Clear App.state() between tests
2. **Mock Events**: Test event handlers in isolation
3. **Context Testing**: Test with different contexts
4. **Log Verification**: Assert on log outputs
5. **Schema Testing**: Validate schemas with test data

## Integration with Business Logic

### Domain Namespace Example

```typescript
export namespace Account {
  // Use core systems
  const log = Log.create({ service: "account" })
  
  const state = App.state("account", () => ({
    accounts: new Map<string, Info>()
  }))
  
  // Define schemas
  export const Info = z.object({
    id: z.string().uuid(),
    name: z.string()
  }).openapi({ ref: "Account" })
  
  // Define events
  export const Event = {
    created: Bus.event("account.created", Info)
  }
  
  // Business operations
  export async function create(data: Omit<Info, 'id'>): Promise<Info> {
    const account = { ...data, id: crypto.randomUUID() }
    
    // Update state
    state().accounts.set(account.id, account)
    
    // Log operation
    log.info("Account created", { accountId: account.id })
    
    // Emit event
    await Bus.publish(Event.created, account)
    
    return account
  }
}
```

## Future Enhancements

### Planned Improvements

1. **Persistence Layer**: Add state serialization
2. **Clustering Support**: Multi-instance coordination
3. **Metrics System**: Performance monitoring
4. **Tracing System**: Distributed tracing support
5. **Plugin System**: Extensible architecture

### Considerations

1. **Memory Management**: Implement cleanup strategies
2. **Event Persistence**: Store events for replay
3. **Configuration Hot-Reload**: Dynamic config updates
4. **Health Monitoring**: System health checks
5. **Rate Limiting**: Request throttling

## Summary

The core infrastructure systems provide a solid foundation for building the Financial Forecasting Engine. By using namespaces, Zod schemas, and event-driven architecture, the system achieves:

- **Type Safety**: Runtime and compile-time validation
- **Modularity**: Clear separation of concerns
- **Testability**: Easy to test in isolation
- **Observability**: Built-in logging and events
- **Simplicity**: Straightforward patterns

These systems work together to create a maintainable, scalable application architecture suitable for the single-player financial forecasting use case.