---
date: 2025-08-19T14:48:43-07:00
researcher: Claude
git_commit: c4647dd6de7c18c66f65100386d98a51a79f2ef6
branch: master
repository: money
topic: "Implementation Roadmap for Financial Forecasting Engine"
tags: [research, implementation, architecture, turborepo, bun, biome, core-systems]
status: complete
last_updated: 2025-08-19
last_updated_by: Claude
---

# Research: Implementation Roadmap for Financial Forecasting Engine

**Date**: 2025-08-19T14:48:43-07:00
**Researcher**: Claude
**Git Commit**: c4647dd6de7c18c66f65100386d98a51a79f2ef6
**Branch**: master
**Repository**: money

## Research Question
Establish the order of operations for implementation, focusing on core systems first, then domain models. Include proper setup for Turborepo, Bun, and Biome to create a headless, in-memory financial planning engine with comprehensive testing.

## Summary
Based on the architecture documents and technology research, the implementation should follow a phased approach starting with project setup, then foundation systems with no dependencies, followed by core infrastructure, and finally domain models. Each phase builds on the previous, allowing for incremental testing and validation.

## Implementation Roadmap

### Phase 1: Foundation Layer (No Dependencies)

These systems can be implemented and tested independently.

#### 1.1 Global System
**File**: `src/system/global.ts`
- XDG base directory specification
- Application-specific paths
- Pure configuration, no behavior
- **Test**: Verify path generation correctness

#### 1.2 Log System
**File**: `src/system/log.ts`
- Service-specific loggers via `Log.create()`
- Level filtering (DEBUG, INFO, WARN, ERROR)
- Timing utilities
- **Test**: Verify log output format and filtering

### Phase 2: Core Infrastructure

Build on foundation layer, minimal interdependencies.

#### 2.1 Config System
**File**: `src/system/config.ts`
- Dependencies: Global, Log
- Zod schema validation
- Multi-source loading (files, environment)
- **Test**: Validate configuration loading and merging

#### 2.2 Context System
**File**: `src/system/context.ts`
- Dependencies: Log
- AsyncLocalStorage wrapper
- Request-scoped context
- **Test**: Verify context isolation and propagation

#### 2.3 Bus System
**File**: `src/system/bus.ts`
- Dependencies: Log
- Type-safe event definitions with Zod
- Synchronous event publishing
- **Test**: Event subscription and publishing

#### 2.4 App System
**File**: `src/system/app.ts`
- Dependencies: Log, Context
- Service lifecycle management
- `App.state()` for singleton services
- `App.provide()` for application context
- **Test**: Service initialization and cleanup

### Phase 3: Advanced Infrastructure

#### 3.1 Transaction System
**File**: `src/system/transaction.ts`
- Dependencies: App, Context, Log, Bus
- Atomic operations with rollback
- Mutation recording
- Optional read isolation
- **Test**: Atomic operations and rollback scenarios

#### 3.2 SortedDateMap Utility
**File**: `src/system/sorted-date-map.ts`
- Standalone data structure
- O(1) lookups, sorted iteration
- Range queries
- **Test**: Sorting, insertion, and range operations

### Phase 4: Domain Models

#### 4.1 Account System
**File**: `src/core/account.ts`
- Dependencies: App, Log, Bus, Transaction
- Account types: Cash, Credit, Vendor
- Balance calculations (O(1))
- **Test**: Account creation, balance computation

#### 4.2 Transfer System
**File**: `src/core/transfer.ts`
- Dependencies: App, Log, Bus, Transaction, SortedDateMap, Account
- State transitions: Projected → Pending → Posted
- Double-entry accounting
- Index management
- **Test**: State transitions, double-entry rules

#### 4.3 Schedule System
**File**: `src/core/schedule.ts`
- Dependencies: App, Log, Bus, Transaction, Transfer
- Recurrence rules
- Transfer generation
- Reconciliation logic
- **Test**: Recurrence patterns, month-end edge cases

### Phase 5: API Layer

#### 5.1 HTTP API
**File**: `src/api/index.ts`
- RESTful endpoints
- Zod validation
- OpenAPI generation
- **Test**: End-to-end API tests

## Testing Strategy

### Testing Principles
1. **No Mocking**: Test real implementations in-memory
2. **Isolated Contexts**: Each test runs in fresh `App.provide()` context
3. **Event Verification**: Capture and assert on domain events
4. **Transaction Testing**: Verify atomic operations

### Test Structure per Phase

#### Foundation Tests
```typescript
describe("Log System", () => {
  test("creates service-specific logger", () => {
    const log = Log.create({ service: "test" })
    expect(log.info).toBeDefined()
  })
})
```

#### Infrastructure Tests
```typescript
describe("Bus System", () => {
  test("publishes typed events", async () => {
    await App.provide(async () => {
      const TestEvent = Bus.event("test", z.object({ value: z.number() }))
      const received: number[] = []
      
      Bus.subscribe(TestEvent, (e) => received.push(e.properties.value))
      await Bus.publish(TestEvent, { value: 42 })
      
      expect(received).toEqual([42])
    })
  })
})
```

#### Domain Tests
```typescript
describe("Account System", () => {
  test("calculates balance from credits and debits", () => {
    App.provide(() => {
      const account = Account.create({
        name: "Test",
        type: "cash",
        credits: 1000n,
        debits: 300n
      })
      
      expect(Account.getCurrentBalance(account.id)).toBe(700)
    })
  })
})
```

## Technology Setup Details

### Turborepo Configuration (Future)
While starting with a single package, the architecture supports future monorepo structure:
- Apps in `apps/` directory
- Shared packages in `packages/`
- Use `@workspace/` naming convention
- Configure `turbo.json` for build pipelines

### Bun Optimizations
- Use `--hot` flag for development hot reloading
- Leverage Bun's built-in test runner
- Native TypeScript execution without compilation
- Fast package installation with `bun.lockb`

### Biome Benefits
- 97% Prettier compatibility
- Significantly faster than ESLint
- Unified formatting and linting
- Type-aware rules for TypeScript

## Critical Implementation Notes

### Dependency Order is Crucial
1. Global and Log have no dependencies - implement first
2. App depends on Context and Log - implement after
3. Transaction depends on App - implement after App
4. Account must exist before Transfer
5. Transfer must exist before Schedule

### State Management Pattern
```typescript
const state = App.state("system-name", () => ({
  // Initialize state Maps and Sets
  entities: new Map<string, Entity>(),
  indexes: new Map<string, Set<string>>()
}))
```

### Event Pattern
```typescript
export const Event = {
  created: Bus.event("entity.created", EntitySchema),
  updated: Bus.event("entity.updated", EntitySchema)
}
```

### Testing Pattern
```typescript
App.provide(() => {
  // All test operations in isolated context
  // State automatically cleaned up
})
```

## Implementation Timeline Estimate

- **Phase 0**: 1 day - Project setup and tooling
- **Phase 1**: 1 day - Foundation systems (Global, Log)
- **Phase 2**: 2 days - Core infrastructure (Config, Context, Bus, App)
- **Phase 3**: 2 days - Advanced infrastructure (Transaction, SortedDateMap)
- **Phase 4**: 3 days - Domain models (Account, Transfer, Schedule)
- **Phase 5**: 2 days - API layer and integration

**Total**: ~11 days for complete implementation with tests

## Open Questions

1. **Persistence**: Architecture marks persistence as future scope - when to add?
2. **Client Interface**: Headless core established, but UI approach undefined
3. **Authentication**: Single-player for now, but hooks for future multi-user?
4. **Deployment**: Single-instance deployment strategy details needed

## Next Steps

1. Initialize project with Bun and configure tooling
2. Implement Global and Log systems with tests
3. Build Config, Context, Bus, App systems incrementally
4. Add Transaction system for atomic operations
5. Implement Account system as first domain model
6. Continue with Transfer and Schedule systems
7. Add API layer for external interaction

## Related Research

- `thoughts/architecture/core-systems.md` - Detailed infrastructure specifications
- `thoughts/architecture/domain-model.md` - Business entity definitions  
- `thoughts/architecture/testing-strategy.md` - Comprehensive testing approach
- `thoughts/architecture/development-workflow.md` - Development environment setup

## Conclusion

The implementation should proceed in phases, starting with foundation systems that have no dependencies, then building up through infrastructure to domain models. Each phase provides testable components that subsequent phases depend on. The combination of Bun for runtime, Biome for code quality, and the namespace architecture pattern provides a clean, performant foundation for the financial forecasting engine.
