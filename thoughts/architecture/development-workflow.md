# Development Workflow

## Project Structure

### Single Package Architecture
The application is organized as a single TypeScript package with namespace-based architecture.

**Repository Layout**:
```
money/
├── package.json               # Project configuration
├── .gitignore
├── biome.json                 # Code formatting/linting config
├── tsconfig.json              # TypeScript configuration
├── bun.lockb                  # Bun lock file
├── src/
│   ├── system/
│   │   └── index.ts          # All system namespaces
│   ├── core/
│   │   ├── account.ts        # Account namespace
│   │   ├── transfer.ts       # Transfer namespace
│   │   └── schedule.ts       # Schedule namespace
│   ├── api/
│   │   └── index.ts          # API handlers
│   └── index.ts              # Application entry point
├── thoughts/
│   └── architecture/          # Architecture documentation
└── tests/                     # Test files
```

### Package Configuration

**package.json**:
```json
{
  "name": "financial-forecasting-engine",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun run --watch src/index.ts",
    "build": "bun build src/index.ts --outdir=dist",
    "test": "bun test",
    "lint": "biome check .",
    "format": "biome format --write .",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@biomejs/biome": "latest",
    "@types/bun": "latest",
    "typescript": "^5.0.0"
  }
}
```

## Technology Stack

### Runtime Environment
**Bun** - JavaScript runtime and toolkit
- Fast TypeScript execution
- Built-in test runner
- Native package manager
- Hot module reloading

### Language and Type System
**TypeScript** - Type-safe JavaScript
- Strict mode enabled
- Latest ECMAScript features
- Namespace-based organization
- Zod for runtime validation

### Code Quality Tools
**Biome** - Fast formatter and linter
- Replaces ESLint and Prettier
- Single configuration file
- IDE integration
- Git hooks integration

### Validation and Schemas
**Zod** - Runtime validation
- Type inference from schemas
- OpenAPI generation
- Request/response validation
- Domain model constraints

## Namespace Development

### System Namespace Pattern
Each system follows a consistent structure in `src/system/index.ts`:

```typescript
import { z } from "zod"
import { Log } from "./log"
import { Bus } from "./bus"
import { App } from "./app"

export namespace Account {
  const log = Log.create({ service: "account" })
  
  // State management
  const state = App.state("account", () => ({
    accounts: new Map<string, Info>(),
    indexes: {
      byType: new Map<string, Set<string>>(),
      byStatus: new Map<string, Set<string>>()
    }
  }))
  
  // Zod schemas
  export const Info = z.object({
    id: z.string().uuid(),
    name: z.string(),
    type: z.enum(["cash", "credit", "vendor"]),
    status: z.enum(["active", "frozen", "closed"])
  }).openapi({ ref: "Account" })
  export type Info = z.infer<typeof Info>
  
  // Events
  export const Event = {
    created: Bus.event("account.created", Info),
    updated: Bus.event("account.updated", Info)
  }
  
  // Business operations
  export function create(data: Omit<Info, 'id'>): Info {
    const account = { ...data, id: crypto.randomUUID() }
    state().accounts.set(account.id, account)
    Bus.publish(Event.created, account)
    return account
  }
}
```

### TypeScript Configuration

**tsconfig.json**:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

## Development Commands

### Project Setup
- `bun install` - Install all dependencies
- `bun run build` - Build all packages
- `bun run dev` - Start development mode

### Development Tasks
- `bun run test` - Run all tests
- `bun run test:watch` - Run tests in watch mode
- `bun run lint` - Check code quality
- `bun run format` - Format code
- `bun run typecheck` - Type checking

### Quick Commands
- `bun run src/index.ts` - Run application directly
- `bun test` - Run all tests
- `bun test --watch` - Run tests in watch mode

## Testing Strategy

### Test Organization
**Unit Tests**:
- Test individual functions and classes
- Mock external dependencies
- Fast execution
- High code coverage

**Integration Tests**:
- Test component interactions
- Use test doubles for infrastructure
- Verify business workflows
- Event flow testing

**End-to-End Tests** (Future):
- Test complete user scenarios
- Real infrastructure components
- Performance benchmarks
- Load testing

### Test Implementation with Bun
```typescript
import { describe, it, expect, beforeEach } from "bun:test"
import { Account } from "../src/system"

describe("Account Namespace", () => {
  beforeEach(() => {
    // Reset state between tests
    App.reset()
  })
  
  it("should create account with generated ID", () => {
    const account = Account.create({
      name: "Test Account",
      type: "cash",
      status: "active"
    })
    
    expect(account.id).toBeDefined()
    expect(account.name).toBe("Test Account")
  })
  
  it("should emit created event", async () => {
    const events: any[] = []
    Bus.subscribe(Account.Event.created, (e) => events.push(e))
    
    Account.create({ name: "Test", type: "cash", status: "active" })
    
    expect(events).toHaveLength(1)
    expect(events[0].properties.name).toBe("Test")
  })
})
```

### Test Coverage Requirements
- Minimum 80% code coverage
- 100% coverage for domain logic
- Integration tests for all use cases
- Performance regression tests

## Code Style Guidelines

### Biome Configuration
```json
{
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "complexity": {
        "noExcessiveCognitiveComplexity": "error"
      },
      "style": {
        "useConst": "error",
        "useTemplate": "error"
      }
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  }
}
```

### Coding Conventions
- Use functional programming where appropriate
- Prefer immutability
- Explicit error handling
- Dependency injection
- Interface-based design

### Naming Conventions
- PascalCase for namespaces and types
- camelCase for functions and variables
- UPPER_SNAKE_CASE for constants
- kebab-case for file names
- Namespace.Event for event definitions
- Namespace.Info for main schema

## Version Control

### Git Workflow
**Branch Strategy**:
- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `fix/*` - Bug fixes
- `chore/*` - Maintenance tasks

**Commit Conventions**:
- Conventional commits format
- Atomic, focused changes
- Clear, descriptive messages
- Reference issues when applicable

**Pull Request Process**:
- Branch from develop
- Write tests first
- Ensure CI passes
- Code review required
- Squash and merge

### CI/CD Pipeline

**Simple Deployment Strategy**:
- Single server deployment
- Stop service, deploy, restart
- Brief downtime acceptable
- Request buffering during restart

**GitHub Actions Workflow**:
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: oven-sh/setup-bun@v1
      - run: bun install
      - run: bun run lint
      - run: bun run typecheck
      - run: bun run test
      - run: bun run build
```

## Documentation Standards

### Code Documentation
- Zod schemas with `.openapi()` for API docs
- Inline comments for complex logic
- Architecture documentation in thoughts/
- Auto-generated OpenAPI from schemas

### Namespace Documentation
```typescript
/**
 * Account management namespace
 * Handles account creation, updates, and balance calculations
 */
export namespace Account {
  // Implementation
}
```

## Development Environment

### Required Tools
- Bun (latest version)
- Git
- VS Code or preferred IDE
- Terminal/Shell

### Recommended VS Code Extensions
- Biome
- TypeScript and JavaScript
- GitLens
- Error Lens
- TODO Highlight

### Environment Setup
```bash
# Clone repository
git clone <repository-url>
cd money

# Install dependencies
bun install

# Run application
bun run dev

# Or run directly
bun run src/index.ts
```

## Performance Monitoring

### Development Metrics
- Build times per package
- Test execution duration
- Memory footprint
- Event processing rates

### Optimization Guidelines
- Memory-efficient data structures
- Garbage collection tuning
- Event handler performance
- Startup time optimization

## Security Practices

### Development Security
- No secrets in code
- Environment variable usage
- Dependency scanning
- Security linting rules

### Code Review Focus
- Input validation
- Error handling
- Authentication checks
- Data sanitization

## Troubleshooting

### Common Issues
**TypeScript Namespace Issues**:
- Ensure all namespaces are exported
- Check circular dependencies
- Verify App.state() initialization

**Zod Validation Errors**:
- Check schema definitions
- Verify `.parse()` vs `.safeParse()`
- Review error messages

**Event Bus Issues**:
- Ensure handlers are registered before publishing
- Check event type names match
- Verify Promise.all() completion

**Memory Issues**:
- Monitor Map/Set sizes in state
- Clear unused data periodically
- Single-player reduces memory needs

**Bun Compatibility**:
- Use latest Bun version
- Check AsyncLocalStorage support
- Review Bun test runner docs