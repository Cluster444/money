# API Design

## Overview

The Financial Forecasting Engine exposes a RESTful HTTP API built on top of the namespace architecture. The single-instance design provides a stateful API server with in-memory data access. Real-time updates via Server-Sent Events (SSE) are planned for future development.

## Design Principles

### RESTful Architecture
- Resource-based URLs
- HTTP methods for operations
- Stateful server with in-memory context
- JSON payloads validated with Zod schemas
- Direct namespace function calls

### Context Flow
- HTTP requests create Context via Context.provide()
- Request context flows through namespace operations
- Automatic context propagation via AsyncLocalStorage
- Request-level mutex for consistency

### Schema Generation
- OpenAPI schemas auto-generated from Zod `.openapi()` calls
- Type-safe request/response validation
- Automatic documentation generation
- Contract-first development

### Future Enhancements
- Real-time updates via SSE/WebSockets
- API versioning and migration
- Authentication and authorization
- Rate limiting and quotas

## Core Endpoints

### Account Management

**GET /api/v1/accounts**
- List all accounts
- Query parameters: type, status, search
- Response: Paginated account list
- Implementation: Calls `Account.list()` namespace function

**GET /api/v1/accounts/:id**
- Retrieve specific account
- Includes computed balance
- Response: Account details with metadata

**POST /api/v1/accounts**
- Create new account
- Request body: Account configuration
- Response: Created account with ID
- Implementation: Calls `Account.create()` and publishes event

**PUT /api/v1/accounts/:id**
- Update account details
- Request body: Partial update fields
- Response: Updated account
- Implementation: Calls `Account.update()` and publishes event

**DELETE /api/v1/accounts/:id**
- Soft delete account
- Validates no pending transfers
- Response: Confirmation
- Implementation: Calls `Account.delete()` and publishes event

**GET /api/v1/accounts/:id/balance**
- Get current balance
- Query parameters: date (for historical)
- Response: Balance details with breakdown

**GET /api/v1/accounts/:id/forecast**
- Project account balances
- Query parameters: startDate, endDate
- Response: Daily balance projections

### Transfer Operations

**GET /api/v1/transfers**
- List transfers
- Query parameters: 
  - accountId: Filter by account
  - status: Filter by state
  - dateFrom/dateTo: Date range
  - limit/offset: Pagination
- Response: Paginated transfer list

**GET /api/v1/transfers/:id**
- Retrieve specific transfer
- Response: Full transfer details

**POST /api/v1/transfers**
- Create new transfer
- Request body: Transfer details
- Response: Created transfer
- Implementation: Calls `Transfer.create()` and publishes event

**PUT /api/v1/transfers/:id**
- Modify transfer (restrictions based on status)
- Request body: Update fields
- Response: Updated transfer
- Implementation: Calls `Transfer.update()` and publishes event

**POST /api/v1/transfers/:id/transition**
- Change transfer status
- Request body: { status, reason }
- Validates state transition rules
- Events: TransferStateChanged

**GET /api/v1/transfers/queue**
- Get transfers requiring action
- Response: Transfers pending user decision
- Real-time: SSE for queue updates

**POST /api/v1/transfers/:id/approve**
- Approve pending transfer
- Moves to posted status
- Events: TransferPosted

**POST /api/v1/transfers/:id/reject**
- Reject pending transfer
- Request body: Rejection reason
- Events: TransferRejected

### Schedule Management

**GET /api/v1/schedules**
- List all schedules
- Query parameters: status, accountId
- Response: Schedule list with next run

**GET /api/v1/schedules/:id**
- Retrieve schedule details
- Includes generated transfers
- Response: Full schedule configuration

**POST /api/v1/schedules**
- Create recurring schedule
- Request body: Schedule configuration
- Response: Created schedule
- Events: ScheduleCreated

**PUT /api/v1/schedules/:id**
- Modify schedule
- Handles projected transfer reconciliation
- Events: ScheduleModified

**POST /api/v1/schedules/:id/pause**
- Temporarily pause schedule
- Response: Updated schedule
- Events: SchedulePaused

**POST /api/v1/schedules/:id/resume**
- Resume paused schedule
- Response: Updated schedule
- Events: ScheduleResumed

**DELETE /api/v1/schedules/:id**
- Delete schedule and projected transfers
- Query parameter: keepExisting (boolean)
- Events: ScheduleDeleted

**POST /api/v1/schedules/:id/generate**
- Manually trigger generation
- Response: Generated transfer IDs
- Events: ScheduleTriggered

### Real-Time Streams (Future Scope)

Server-Sent Events (SSE) endpoints for real-time updates will be implemented in future development cycles. Current implementation uses polling or request-response patterns.

### System Operations

**GET /api/v1/system/health**
- Health check endpoint
- Response: System status and metrics

**GET /api/v1/system/info**
- System information
- Version, capabilities, limits
- Response: System metadata

**POST /api/v1/system/maintenance/daily**
- Trigger daily maintenance
- Schedule generation, cleanup
- Response: Task results
- Events: MaintenanceCompleted

## Request/Response Formats

### Standard Request Headers
```
Content-Type: application/json
Accept: application/json
X-Request-ID: <uuid>
Authorization: Bearer <token> (future scope)
```

### Standard Response Format
```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2024-01-01T00:00:00Z",
    "version": "1.0.0",
    "requestId": "uuid"
  },
  "links": {
    "self": "/api/v1/resource/123",
    "related": { ... }
  }
}
```

### Error Response Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid transfer amount",
    "details": [
      {
        "field": "amount",
        "issue": "Must be positive"
      }
    ],
    "timestamp": "2024-01-01T00:00:00Z",
    "requestId": "uuid"
  }
}
```

### Pagination Format
```json
{
  "data": [ ... ],
  "meta": {
    "total": 100,
    "limit": 20,
    "offset": 0,
    "hasNext": true,
    "hasPrev": false
  },
  "links": {
    "next": "/api/v1/resource?offset=20",
    "prev": null,
    "first": "/api/v1/resource?offset=0",
    "last": "/api/v1/resource?offset=80"
  }
}
```

## Implementation Pattern

### API Handler Example
```typescript
export namespace API {
  const log = Log.create({ service: "api" })
  
  export function createAccount(req: Request): Response {
    // Create context for request
    return Context.provide({ requestId: req.id }, () => {
      // Wrap in transaction for consistency
      const tx = Transaction.begin()
      try {
        const result = tx.run(() => {
          // Validate with Zod
          const data = Account.Info.parse(req.body)
          
          // Call namespace function
          const account = Account.create(data)
          
          return account
        })
        
        tx.commit()
        
        // Return response
        return {
          data: result,
          meta: { timestamp: new Date() }
        }
      } catch (error) {
        tx.rollback()
        throw error
      }
    })
  }
}
```

### OpenAPI Generation
Schemas are automatically generated from Zod definitions:
```typescript
// In namespace
export const Info = z.object({
  // schema
}).openapi({ ref: "Account" })

// Generates OpenAPI spec
const spec = generateOpenAPIFromZod()
```

## Validation with Zod

### Input Validation
```typescript
const CreateAccountRequest = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(["cash", "credit", "vendor"]),
  metadata: z.record(z.any()).optional()
})

// In handler
const validated = CreateAccountRequest.parse(req.body)
```

### Output Validation
- Automatic from Zod schemas
- Type-safe responses
- Consistent error format
- Schema-driven documentation

## Security Considerations

### Current Security
- Input validation via Zod
- Type-safe operations
- Single-player reduces attack surface

### Future Security Enhancements
- Authentication (JWT, OAuth 2.0)
- Authorization (RBAC)
- Rate limiting
- API keys
- Session management

### Security Headers
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
```

## Performance Optimization

### Performance Benefits
- Instant memory access
- No database round-trips
- Immediate response from cache
- Zero network latency internally

### Response Optimization
- Direct memory serialization
- Field filtering (?fields=id,name)
- Nested resource expansion (?expand=account)
- Efficient pagination from memory

### Connection Efficiency
- Keep-alive connections
- Single server simplifies management
- No inter-service communication
- Direct client-to-engine connection

## API Documentation

### OpenAPI Generation
- Auto-generated from Zod schemas
- `.openapi()` method for documentation
- Type-safe contract
- Interactive Swagger UI

### Future Enhancements
- Client SDK generation
- API versioning
- Migration guides
- Usage examples

## Monitoring (Future Scope)

Comprehensive monitoring and analytics will be implemented in future development cycles:
- Request/response logging
- Performance metrics
- Error tracking
- Health checks
- Usage analytics