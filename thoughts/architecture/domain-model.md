# Domain Model

## Core Design Principles

### Double-Entry Accounting
- Every financial transaction affects at least two accounts
- Debits and credits must balance
- Account balances are derived, not stored
- Immutable transaction history

### Temporal Modeling
- Daily granularity for all financial operations
- Simple Date objects (timezone handling is future scope)
- Projected transactions for forecasting
- In-memory historical data

### State Management
- Explicit state transitions for transfers
- Synchronous event emission for state changes
- Computed properties over stored values
- Consistency through Zod validation and domain rules
- Atomic operations via Transaction system for multi-step changes

## Implementation Pattern

Each domain entity is implemented as a namespace with the following structure:

```typescript
export namespace EntityName {
  const log = Log.create({ service: "entity-name" })
  
  // State management
  const state = App.state("entity-name", () => ({
    entities: new Map<string, Info>()
  }))
  
  // Zod schema for validation
  export const Info = z.object({
    // Schema definition
  }).openapi({ ref: "EntityName" })
  export type Info = z.infer<typeof Info>
  
  // Event definitions
  export const Event = {
    created: Bus.event("entity.created", Info),
    updated: Bus.event("entity.updated", Info)
  }
  
  // Business operations
  export function create(data: Omit<Info, 'id'>): Info { }
  export function calculateBalance(id: string): number { }
}
```

## Entity Definitions

### Account

**Purpose**: Represents a financial account that can hold money or debt

**Types**:
- **Cash Account**: Physical money or bank accounts
  - Can have positive balance (funds available)
  - May support overdraft (configurable)
  - Used for checking, savings, cash on hand
  
- **Credit Account**: Debt instruments requiring repayment
  - Always negative or zero balance
  - Has credit limit
  - Subtypes for different behaviors:
    - Credit Card: Revolving credit with minimum payments
    - Loan: Fixed payments with amortization
    - Line of Credit: Flexible borrowing

- **Vendor Account**: External entities for double-entry
  - Represents money sources/destinations
  - Examples: Employers, merchants, service providers
  - No balance constraints

**Zod Schema Definition**:
```typescript
export const Info = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(100),
  type: z.enum(["cash", "credit", "vendor"]),
  credits: z.bigint().min(0n),  // Total credits posted to account
  debits: z.bigint().min(0n),   // Total debits posted to account
  metadata: z.discriminatedUnion("type", [
    z.object({
      type: z.literal("cash"),
      overdraftEnabled: z.boolean().default(false),
      overdraftLimit: z.number().min(0).optional()
    }),
    z.object({
      type: z.literal("credit"),
      creditLimit: z.number().min(0),
      apr: z.number().min(0).max(100),
      paymentTerms: z.object({
        minimumPayment: z.number().min(0),
        dueDay: z.number().min(1).max(31)
      }).optional()
    }),
    z.object({
      type: z.literal("vendor"),
      vendorType: z.string().optional()
    })
  ]),
  createdAt: z.date(),
  status: z.enum(["active", "frozen", "closed"])
}).openapi({ ref: "Account" })
```

**Computed Properties**:
- `currentBalance`: credits - debits (O(1) calculation)
- `pendingBalance`: currentBalance + sum of pending transfers
- `projectedBalance(date)`: pendingBalance + projected transfers up to date
- `availableCredit`: For credit accounts only
- `utilizationRate`: For credit accounts only

### Transfer

**Purpose**: Represents money movement between accounts

**States**:
- **Projected**: Scheduled but not yet due
  - Can be modified or cancelled
  - Generated from schedules or manually created
  - Does not affect account credits/debits
  
- **Pending**: In processing queue
  - Awaiting confirmation or processing
  - Affects pending balance calculations
  - Can be modified with restrictions
  
- **Posted**: Completed and immutable
  - Updates account credits/debits
  - Cannot be modified (only reversed)
  - Part of permanent record

**Zod Schema Definition**:
```typescript
export const Info = z.object({
  id: z.string().uuid(),
  date: z.date(),
  status: z.enum(["projected", "pending", "posted"]),
  fromAccountId: z.string().uuid(),
  toAccountId: z.string().uuid(),
  amount: z.bigint().positive(),  // Amount in cents
  description: z.string().max(500),
  metadata: z.object({
    scheduleId: z.string().uuid().optional(),
    modificationHistory: z.array(z.object({
      timestamp: z.date(),
      change: z.string()
    })).optional(),
    externalReference: z.string().optional()
  }).optional(),
  createdAt: z.date(),
  updatedAt: z.date(),
  postedAt: z.date().optional()
}).refine(data => data.fromAccountId !== data.toAccountId, {
  message: "Cannot transfer to same account"
}).openapi({ ref: "Transfer" })
```

**Business Rules**:
- Amount must be positive (stored as bigint cents)
- Cannot transfer to same account
- State transitions: Projected → Pending → Posted
- Posted transfers update account credits/debits atomically
- No pre-validation of account balances (system reflects, not enforces)
- Schedule-generated transfers (with scheduleId) are immutable to users
- One-off projected transfers (no scheduleId) can be modified by users

### Schedule

**Purpose**: Template for generating recurring transfers

**Recurrence Patterns**:
- **Daily**: Every N days
- **Weekly**: Single day of week only (simplified from multi-day)
  - Specified as day number (0=Sunday, 6=Saturday)
- **Monthly**: Specific day of month
  - Month-end edge case: If day doesn't exist (e.g., 31st in February), use last valid day
  - Example: 31st → Feb 28/29 → Mar 31st → Apr 30th → May 31st
- **Yearly**: Specific day and month

**Zod Schema Definition**:
```typescript
export const RecurrenceRule = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("daily"),
    interval: z.number().min(1)
  }),
  z.object({
    type: z.literal("weekly"),
    interval: z.number().min(1),
    dayOfWeek: z.number().min(0).max(6)  // Single day only
  }),
  z.object({
    type: z.literal("monthly"),
    interval: z.number().min(1),
    dayOfMonth: z.number().min(1).max(31)
  }),
  z.object({
    type: z.literal("yearly"),
    interval: z.number().min(1),
    month: z.number().min(0).max(11),
    dayOfMonth: z.number().min(1).max(31)
  })
])

export const Info = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(200),
  fromAccountId: z.string().uuid(),
  toAccountId: z.string().uuid(),
  amount: z.bigint().positive(),  // Amount in cents
  recurrenceRule: RecurrenceRule,
  startDate: z.date(),
  endDate: z.date().optional(),
  nextGenerationDate: z.date(),
  horizonDays: z.number().min(1).max(365).default(90),
  status: z.enum(["active", "paused", "completed"]),
  metadata: z.object({
    skipWeekends: z.boolean().optional(),
    skipHolidays: z.boolean().optional()
  }).optional()
}).openapi({ ref: "Schedule" })
```

**Generation Logic**:
- Creates Projected transfers up to horizon
- Handles schedule modifications with smart reconciliation:
  - Amount changes: Update existing transfers in place
  - Date changes: Update dates and re-index
  - Frequency changes: Delete and regenerate all
- Maintains referential integrity via schedule index

## Namespace Implementation Examples

### Account Namespace
```typescript
export namespace Account {
  const log = Log.create({ service: "account" })
  
  const state = App.state("account", () => ({
    accounts: new Map<string, Info>(),
    balanceCache: new Map<string, number>()
  }))
  
  export const Event = {
    created: Bus.event("account.created", Info),
    updated: Bus.event("account.updated", Info),
    balanceChanged: Bus.event("account.balance.changed", z.object({
      accountId: z.string(),
      oldBalance: z.number(),
      newBalance: z.number()
    }))
  }
  
  export function create(data: Omit<Info, 'id'>): Info {
    const account = { ...data, id: crypto.randomUUID() }
    state().accounts.set(account.id, account)
    Bus.publish(Event.created, account)
    return account
  }
  
  export function calculateBalance(accountId: string): number {
    // Sum all posted transfers affecting this account
    // Implementation in Transfer namespace
    return Transfer.getAccountBalance(accountId)
  }
}
```

## Relationships

### Account ↔ Transfer
- One-to-many: Account has many transfers
- Transfers reference source and destination accounts
- Bidirectional navigation required

### Schedule ↔ Transfer
- One-to-many: Schedule generates many transfers
- Transfers maintain reference to originating schedule
- Orphaned transfers when schedule deleted

### Account ↔ Schedule
- Many-to-many: Accounts involved in multiple schedules
- Schedules reference source and destination accounts

## Value Objects as Zod Schemas

### Money
```typescript
// Money is always stored as cents using bigint for precision
// This provides the equivalent of u64 in TypeScript
export type Money = bigint  // Always in cents

// Helper functions for conversion
export const toDollars = (cents: Money): number => Number(cents) / 100
export const fromDollars = (dollars: number): Money => BigInt(Math.round(dollars * 100))

// Zod schema for API validation (accepts dollars, converts to cents)
export const MoneySchema = z.number()
  .transform(dollars => fromDollars(dollars))
  .or(z.bigint())
```

### DateOnly
```typescript
// Using simple Date objects for now
// Timezone handling is future scope
export const DateOnly = z.date().transform(date => {
  // Zero out time components
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
})
```

## Aggregates via App.state()

### Account Aggregate
```typescript
const state = App.state("account", () => ({
  accounts: new Map<string, Account.Info>(),
  transfersByAccount: new Map<string, Set<string>>(),
  schedulesByAccount: new Map<string, Set<string>>()
}))
```

### Transfer Processing Aggregate
```typescript
const state = App.state("transfer", () => ({
  transfers: new Map<string, Transfer.Info>(),
  
  // Critical indexes for performance
  byAccountAndDate: new Map<string, SortedDateMap<Set<string>>>(),  // See core-systems.md for SortedDateMap
  bySchedule: new Map<string, Set<string>>(),
  pendingTransfers: new Set<string>(),
  projectedTransfers: new Set<string>()
}))
```

**Index Usage**:
- `byAccountAndDate`: For balance projections and account views
- `bySchedule`: For schedule reconciliation operations
- `pendingTransfers`: Quick access for pending balance calculations
- `projectedTransfers`: Quick access for forecasting

### Schedule Management Aggregate
```typescript
const state = App.state("schedule", () => ({
  schedules: new Map<string, Schedule.Info>(),
  generatedTransfers: new Map<string, Set<string>>(),
  nextGenerationDates: new Map<string, Date>()
}))
```

## Domain Services as Namespace Functions

### Transaction Boundaries
Complex operations that modify multiple entities should be wrapped in transactions to ensure consistency. The Transaction system (see core-systems.md) provides automatic rollback if any step fails, preventing partial state changes.

### Balance Calculator
```typescript
export namespace Account {
  // O(1) current balance
  export function getCurrentBalance(accountId: string): number {
    const account = state().accounts.get(accountId)
    return Number(account.credits - account.debits)
  }
  
  // Pending balance includes pending transfers
  export function getPendingBalance(accountId: string): number {
    let balance = getCurrentBalance(accountId)
    
    for (const transferId of Transfer.state().pendingTransfers) {
      const transfer = Transfer.get(transferId)
      if (transfer.fromAccountId === accountId) balance -= transfer.amount
      if (transfer.toAccountId === accountId) balance += transfer.amount
    }
    
    return balance
  }
  
  // Projected balance up to specific date
  export function getProjectedBalance(accountId: string, date: Date): number {
    let balance = getPendingBalance(accountId)
    
    const accountTransfers = Transfer.state().byAccountAndDate.get(accountId)
    if (!accountTransfers) return balance
    
    // Iterate transfers up to target date
    for (const [transferDate, transferIds] of accountTransfers) {
      if (transferDate > date) break
      
      for (const transferId of transferIds) {
        const transfer = Transfer.get(transferId)
        if (transfer.status !== 'projected') continue
        
        if (transfer.fromAccountId === accountId) balance -= transfer.amount
        if (transfer.toAccountId === accountId) balance += transfer.amount
      }
    }
    
    return balance
  }
}
```

### Transfer Processor
```typescript
export namespace Transfer {
  export async function transition(id: string, newStatus: Status): Promise<void> {
    const transfer = state().transfers.get(id)
    if (!transfer) throw new Error("Transfer not found")
    
    validateTransition(transfer.status, newStatus)
    const oldStatus = transfer.status
    transfer.status = newStatus
    
    // Index updates happen within transaction context
    // These mutations are recorded and applied on commit
    if (oldStatus === 'projected') state().projectedTransfers.delete(id)
    if (oldStatus === 'pending') state().pendingTransfers.delete(id)
    
    if (newStatus === 'pending') {
      state().pendingTransfers.add(id)
    }
    
    if (newStatus === 'posted') {
      transfer.postedAt = new Date()
      
      // Update account credits/debits atomically
      const fromAccount = Account.get(transfer.fromAccountId)
      const toAccount = Account.get(transfer.toAccountId)
      
      fromAccount.debits += transfer.amount  // Already bigint
      toAccount.credits += transfer.amount  // Already bigint
      
      // Update date-based indexes
      updateAccountDateIndex(transfer.fromAccountId, transfer.date, id)
      updateAccountDateIndex(transfer.toAccountId, transfer.date, id)
      
      await Bus.publish(Event.posted, transfer)
    }
  }
  
  // Helper to update the SortedDateMap indexes
  function updateAccountDateIndex(accountId: string, date: Date, transferId: string): void {
    let accountIndex = state().byAccountAndDate.get(accountId)
    if (!accountIndex) {
      accountIndex = new SortedDateMap<Set<string>>()
      state().byAccountAndDate.set(accountId, accountIndex)
    }
    
    let dateTransfers = accountIndex.get(date)
    if (!dateTransfers) {
      dateTransfers = new Set<string>()
      accountIndex.set(date, dateTransfers)
    }
    
    dateTransfers.add(transferId)
  }
}
```

### Schedule Generator
```typescript
export namespace Schedule {
  // Calculate next occurrence based on recurrence rule
  function calculateNextOccurrence(rule: RecurrenceRule, currentDate: Date): Date {
    const next = new Date(currentDate)
    
    switch (rule.type) {
      case 'daily':
        next.setDate(next.getDate() + rule.interval)
        break
        
      case 'weekly':
        // Add weeks and adjust to the specified day
        next.setDate(next.getDate() + (7 * rule.interval))
        break
        
      case 'monthly':
        // Add months but handle day truncation
        const targetDay = rule.dayOfMonth
        next.setMonth(next.getMonth() + rule.interval)
        
        // Handle month-end edge cases (e.g., 31st -> Feb 28/29)
        const daysInMonth = new Date(next.getFullYear(), next.getMonth() + 1, 0).getDate()
        next.setDate(Math.min(targetDay, daysInMonth))
        break
        
      case 'yearly':
        next.setFullYear(next.getFullYear() + rule.interval)
        // Handle Feb 29 in non-leap years
        if (next.getMonth() !== rule.month) {
          next.setDate(next.getDate() - 1)  // Adjust to Feb 28
        }
        break
    }
    
    return next
  }
  
  export function generateTransfers(scheduleId: string): Transfer.Info[] {
    const schedule = state().schedules.get(scheduleId)
    if (!schedule) throw new Error("Schedule not found")
    
    const transfers: Transfer.Info[] = []
    let nextDate = schedule.nextGenerationDate
    const horizon = addDays(new Date(), schedule.horizonDays)
    
    while (nextDate <= horizon) {
      const transfer = Transfer.create({
        fromAccountId: schedule.fromAccountId,
        toAccountId: schedule.toAccountId,
        amount: schedule.amount,
        date: nextDate,
        status: "projected",
        metadata: { scheduleId }
      })
      
      // Update indexes
      Transfer.state().bySchedule.get(scheduleId)?.add(transfer.id)
      transfers.push(transfer)
      
      nextDate = calculateNextOccurrence(schedule.recurrenceRule, nextDate)
    }
    
    return transfers
  }
  
  export function reconcile(scheduleId: string, changes: Partial<Info>): void {
    const existingTransferIds = Transfer.state().bySchedule.get(scheduleId) || new Set()
    
    if (changes.amount && !changes.recurrenceRule) {
      // Simple amount change - update in place
      for (const transferId of existingTransferIds) {
        const transfer = Transfer.get(transferId)
        if (transfer.status === 'projected') {
          transfer.amount = changes.amount
        }
      }
    } else if (changes.date && !changes.recurrenceRule) {
      // Date change - update and re-index
      for (const transferId of existingTransferIds) {
        const transfer = Transfer.get(transferId)
        if (transfer.status === 'projected') {
          // Remove from old date index, update date, add to new index
          Transfer.reindexByDate(transferId, transfer.date, changes.date)
          transfer.date = changes.date
        }
      }
    } else if (changes.recurrenceRule) {
      // Frequency change - delete and regenerate
      for (const transferId of existingTransferIds) {
        const transfer = Transfer.get(transferId)
        if (transfer.status === 'projected') {
          Transfer.delete(transferId)
        }
      }
      generateTransfers(scheduleId)
    }
  }
}
```

### Notification Manager (Future Scope)
Notification system will be implemented in a future development cycle.

## Invariants

### System-Wide
- Total debits equal total credits across all accounts
- No money creation or destruction (double-entry maintained)
- Posted transfers are immutable
- Unique transfer identifiers
- Credits and debits are monotonically increasing

### Account-Level
- Credits and debits never decrease (only increase when transfers post)
- Current balance = credits - debits (always)
- Vendor accounts have no balance constraints
- Account balance validation is post-hoc (system reflects, not enforces)

### Transfer-Level
- Positive amounts only (stored as bigint cents)
- Valid account references
- State transitions: Projected → Pending → Posted (one-way)
- Only posted transfers affect account credits/debits
- Proper date sequencing maintained in indexes
- Schedule-generated transfers cannot be user-modified
- Index updates occur only on transaction commit

### Schedule-Level
- Valid recurrence patterns
- Projected transfers within horizon
- No duplicate generation
- Reconciliation maintains referential integrity
- All projected transfers linked to schedules via index