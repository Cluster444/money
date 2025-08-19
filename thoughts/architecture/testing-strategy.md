# Testing Strategy

## Overview

This document outlines the testing strategy for the Financial Forecasting Engine, a headless in-memory application. The testing approach emphasizes **direct testing without mocks**, leveraging the in-memory architecture to create fast, deterministic tests that validate actual implementations rather than stubs.

## Core Testing Principles

### No Mocking Philosophy
All tests interact with real implementations. Since the entire system runs in-memory with no external dependencies, we can test actual behavior rather than mocked interfaces. This ensures tests validate real system behavior and catch integration issues early.

### State Isolation Pattern
Each test runs in a fresh `App.provide()` context, ensuring complete isolation between tests. State is initialized per-test and automatically cleaned up, preventing test interference.

### Event-Driven Verification
Tests capture and assert on domain events to verify system behavior. This validates not just the final state but also the sequence of state transitions.

### Transaction-Based Consistency
The Transaction system provides atomic operations for tests, allowing complex multi-step operations to be tested with automatic rollback on failure.

## Test Organization Structure

```
tests/
├── unit/
│   ├── infrastructure/     # Core system tests
│   └── domain/             # Business logic tests
├── integration/            # Cross-system interaction tests
├── e2e/                   # Complete user workflow tests
└── helpers/               # Shared test utilities
```

## Testing Patterns

### Pattern 1: Test Context Isolation

Every test creates an isolated application context that provides fresh state:

```typescript
describe("Feature", () => {
  test("behavior", () => {
    App.provide(() => {
      // Test runs in isolated context
      const account = Account.create({ name: "Test", type: "cash" })
      
      // All state changes are isolated to this test
      expect(Account.get(account.id)).toBeDefined()
    })
    // State automatically cleaned up after test
  })
})
```

### Pattern 2: Event Capture and Verification

Tests can capture all events to verify system behavior:

```typescript
test("transfer lifecycle emits correct events", async () => {
  await App.provide(async () => {
    const events: any[] = []
    Bus.subscribe("*", (e) => events.push(e))
    
    // Create and transition transfer
    const transfer = Transfer.create({ /* ... */ })
    await Transfer.transition(transfer.id, "posted")
    
    // Verify event sequence
    const eventTypes = events.map(e => e.type)
    expect(eventTypes).toContain("transfer.created")
    expect(eventTypes).toContain("transfer.posted")
  })
})
```

### Pattern 3: Test Data Factories

Consistent test data creation through factory helpers:

```typescript
namespace TestHelpers {
  export function createTestAccounts() {
    return App.provide(() => {
      const checking = Account.create({
        name: "Checking",
        type: "cash",
        credits: 1000n,
        debits: 0n,
        metadata: { type: "cash", overdraftEnabled: true },
        status: "active"
      })
      
      const creditCard = Account.create({
        name: "Credit Card", 
        type: "credit",
        credits: 0n,
        debits: 0n,
        metadata: { 
          type: "credit",
          creditLimit: 5000,
          apr: 18.99
        },
        status: "active"
      })
      
      return { checking, creditCard }
    })
  }
}
```

### Pattern 4: Transaction Testing

Verify atomic operations and rollback behavior:

```typescript
test("atomic multi-entity operations", () => {
  App.provide(() => {
    // Test successful transaction
    Transaction.begin(() => {
      const t1 = Transfer.create({ /* transfer 1 */ })
      const t2 = Transfer.create({ /* transfer 2 */ })
      // Both transfers committed atomically
    })
    
    // Test rollback on failure
    expect(() => {
      Transaction.begin(() => {
        Transfer.create({ /* ... */ })
        throw new Error("Rollback!")
      })
    }).toThrow()
    // No partial state changes
  })
})
```

## Test Categories

### Unit Tests: Infrastructure Systems

Tests for core infrastructure components in isolation:

```typescript
describe("Bus System", () => {
  test("typed event publishing", async () => {
    // Define typed event with Zod schema
    const TestEvent = Bus.event("test.event", z.object({
      value: z.number()
    }))
    
    const received: number[] = []
    Bus.subscribe(TestEvent, (e) => {
      received.push(e.properties.value)
    })
    
    await Bus.publish(TestEvent, { value: 42 })
    expect(received).toEqual([42])
  })
  
  test("schema validation on publish", async () => {
    const StrictEvent = Bus.event("strict", z.object({
      required: z.string()
    }))
    
    // Invalid data rejected by Zod
    await expect(
      Bus.publish(StrictEvent, { required: 123 } as any)
    ).toThrow()
  })
})
```

### Unit Tests: Domain Models

Tests for business logic and domain rules:

```typescript
describe("Account System", () => {
  test("balance calculations", () => {
    App.provide(() => {
      const account = Account.create({ /* ... */ })
      
      // Post transfers to affect balance
      Transfer.create({
        toAccountId: account.id,
        amount: 500n,
        status: "posted"
      })
      
      expect(Account.getCurrentBalance(account.id)).toBe(500)
    })
  })
  
  test("projected balance with future transfers", () => {
    App.provide(() => {
      const account = Account.create({ /* ... */ })
      const futureDate = addDays(new Date(), 30)
      
      // Create projected transfers
      Transfer.create({
        fromAccountId: account.id,
        amount: 200n,
        status: "projected",
        date: addDays(new Date(), 15)
      })
      
      const projected = Account.getProjectedBalance(account.id, futureDate)
      expect(projected).toBe(-200)
    })
  })
})
```

### Integration Tests

Tests for cross-system interactions:

```typescript
describe("Schedule-Transfer Integration", () => {
  test("schedule generates transfers within horizon", () => {
    App.provide(() => {
      const { checking, employer } = TestHelpers.createTestAccounts()
      
      // Create bi-weekly paycheck schedule
      const schedule = Schedule.create({
        name: "Paycheck",
        fromAccountId: employer.id,
        toAccountId: checking.id,
        amount: 2500n,
        recurrenceRule: {
          type: "weekly",
          interval: 2,
          dayOfWeek: 5 // Friday
        },
        startDate: new Date(),
        horizonDays: 60,
        status: "active"
      })
      
      // Verify transfers created and indexed
      const transfers = Schedule.generateTransfers(schedule.id)
      expect(transfers.length).toBeGreaterThanOrEqual(4) // ~4 paychecks in 60 days
      
      // Verify schedule linkage
      transfers.forEach(t => {
        expect(t.metadata?.scheduleId).toBe(schedule.id)
      })
    })
  })
})
```

### End-to-End Tests

Complete user workflow scenarios:

```typescript
describe("E2E: Credit Card Payment Cycle", () => {
  test("monthly payment reduces debt", async () => {
    await App.provide(async () => {
      // Setup accounts with debt
      const checking = Account.create({
        name: "Checking",
        type: "cash",
        credits: 3000n,
        debits: 0n
      })
      
      const creditCard = Account.create({
        name: "Credit Card",
        type: "credit",
        credits: 0n,
        debits: 1500n, // $1500 debt
        metadata: {
          type: "credit",
          creditLimit: 5000
        }
      })
      
      // Schedule monthly payments
      const schedule = Schedule.create({
        name: "CC Payment",
        fromAccountId: checking.id,
        toAccountId: creditCard.id,
        amount: 500n,
        recurrenceRule: {
          type: "monthly",
          interval: 1,
          dayOfMonth: 25
        },
        startDate: new Date(),
        horizonDays: 90
      })
      
      // Process first payment
      const payments = Schedule.generateTransfers(schedule.id)
      await Transfer.transition(payments[0].id, "pending")
      await Transfer.transition(payments[0].id, "posted")
      
      // Verify balances updated
      expect(Account.getCurrentBalance(checking.id)).toBe(2500)
      expect(Account.getCurrentBalance(creditCard.id)).toBe(-1000)
    })
  })
})
```

## Performance Testing

Validate system performance under load:

```typescript
describe("Performance", () => {
  test("handles 10,000 transfers efficiently", () => {
    App.provide(() => {
      const account = Account.create({ /* ... */ })
      
      // Generate many transfers
      const start = performance.now()
      for (let i = 0; i < 10000; i++) {
        Transfer.create({
          fromAccountId: account.id,
          toAccountId: "vendor",
          amount: BigInt(i),
          status: "posted",
          date: new Date()
        })
      }
      const duration = performance.now() - start
      
      // Should handle 10k transfers quickly
      expect(duration).toBeLessThan(1000) // Under 1 second
      
      // Balance calculation should remain O(1)
      const calcStart = performance.now()
      Account.getCurrentBalance(account.id)
      const calcDuration = performance.now() - calcStart
      
      expect(calcDuration).toBeLessThan(10) // Under 10ms
    })
  })
})
```

## Special Testing Considerations

### SortedDateMap Testing

The custom SortedDateMap data structure requires specific tests:

```typescript
test("maintains sorted order", () => {
  const map = new SortedDateMap<number>()
  
  // Insert out of order
  map.set(new Date("2024-03-01"), 3)
  map.set(new Date("2024-01-01"), 1)
  map.set(new Date("2024-02-01"), 2)
  
  // Verify sorted iteration
  const values = Array.from(map).map(([_, v]) => v)
  expect(values).toEqual([1, 2, 3])
})

test("range queries", () => {
  const map = new SortedDateMap<string>()
  
  // Populate with daily data
  for (let i = 1; i <= 31; i++) {
    map.set(new Date(`2024-01-${i}`), `day${i}`)
  }
  
  // Query specific range
  const week = Array.from(
    map.range(new Date("2024-01-07"), new Date("2024-01-14"))
  )
  
  expect(week).toHaveLength(8) // Inclusive range
})
```

### Month-End Edge Cases

Testing schedule recurrence with month-end dates:

```typescript
test("handles month-end correctly", () => {
  App.provide(() => {
    const schedule = Schedule.create({
      recurrenceRule: {
        type: "monthly",
        interval: 1,
        dayOfMonth: 31 // Last day
      },
      startDate: new Date("2024-01-31"),
      horizonDays: 90
    })
    
    const transfers = Schedule.generateTransfers(schedule.id)
    
    // February should use last valid day
    const feb = transfers.find(t => t.date.getMonth() === 1)
    expect(feb!.date.getDate()).toBeLessThanOrEqual(29)
    
    // April (30 days) should use 30th
    const apr = transfers.find(t => t.date.getMonth() === 3)
    expect(apr!.date.getDate()).toBe(30)
  })
})
```

## Test Execution

### Commands

```json
{
  "scripts": {
    "test": "bun test",
    "test:unit": "bun test tests/unit",
    "test:integration": "bun test tests/integration",
    "test:e2e": "bun test tests/e2e",
    "test:watch": "bun test --watch",
    "test:coverage": "bun test --coverage"
  }
}
```

### Coverage Goals

- **Unit Tests**: 90% coverage of business logic
- **Integration Tests**: All cross-system interactions
- **E2E Tests**: Top 10 user workflows
- **Edge Cases**: Date boundaries, state transitions, overdrafts

## Best Practices

1. **Test Independence**: Each test must be runnable in isolation
2. **Clear Assertions**: Test one behavior per test case
3. **Descriptive Names**: Test names should describe the behavior being tested
4. **Fast Execution**: Leverage in-memory architecture for sub-second test runs
5. **No External Dependencies**: Tests should never require network, disk, or database access
6. **Event Verification**: Always verify both state changes and emitted events
7. **Error Testing**: Test both success and failure paths

## Summary

This testing strategy leverages the in-memory, single-instance architecture to create a robust test suite without mocks or external dependencies. By testing real implementations in isolated contexts, we ensure tests accurately reflect production behavior while maintaining fast execution and deterministic results.