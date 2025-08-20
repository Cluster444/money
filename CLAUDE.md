# AGENT INSTRUCTIONS

This file provides guidance to general purpose agents

## Repository Overview

A sophisticated financial forecasting engine built as a Turborepo monorepo using Bun and TypeScript. The system implements double-entry accounting with in-memory state management and an event-driven architecture using TypeScript namespaces instead of traditional classes.

### Components

- `packages/config/` - Shared TypeScript and Biome configurations for workspace packages
- `packages/core/` - Core business logic including accounting engine and forecasting system
- `thoughts/architecture/` - Comprehensive system design and architecture documentation
- `thoughts/research/` - Implementation roadmaps and research notes

### Core Concepts

- **Namespace Architecture**: All systems implemented as TypeScript namespaces with consistent structure (state, schemas, events, operations)
- **In-Memory State**: Single-instance server with all data in memory, balances computed from transaction history
- **Event-Driven**: Synchronous in-process event bus with type-safe Zod schemas
- **Double-Entry Accounting**: Balances computed from debits/credits, never stored directly
- **Transfer State Machine**: Projected → Pending → Posted lifecycle for all transfers

## Development Commands

### Build & Development
- `bun run build` - Build all packages via Turborepo
- `bun run dev` - Start development mode for all packages
- `bun run clean` - Clean all build artifacts and dependencies

### Code Quality
- `bun run check` - Run all checks across packages
- `bun run format` - Format code using Biome
- `bun run lint` - Lint and fix code using Biome
- `bun run typecheck` - Run TypeScript type checking

### Testing
- `bun run test` - Run tests across all packages
- `bun test --watch` - Run tests in watch mode
- `bun test --coverage` - Run tests with coverage reporting

## Technical Guidelines

- **Runtime**: Bun (v1.2.20+) for TypeScript execution and package management
- **Language**: TypeScript (v5.9+) with strict mode enabled
- **Monorepo**: Turborepo for build orchestration
- **Validation**: Zod for runtime type validation and schema definitions
- **Code Quality**: Biome for formatting and linting (97% Prettier compatible)
- **Testing**: Bun's built-in test runner

## Development Conventions

- Use TypeScript namespaces for system modules (not classes)
- Place all system and domain namespaces in `src/[namespace]/index.ts` (e.g., `src/app/index.ts`, `src/account/index.ts`)
- Define all events with Zod schemas for type safety
- Prefer computed values over stored state (e.g., balances from transaction history)
- Use Bun instead of Node.js or npm for all JavaScript/TypeScript operations

## Additional Resources

- `thoughts/architecture/system-architecture.md` - Complete system design documentation
- `thoughts/research/implementation-roadmap.md` - Development phases and priorities
- `packages/config/` - Shared TypeScript configuration examples
- Root `biome.json` - Code formatting and linting rules