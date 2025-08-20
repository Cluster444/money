# Configuration Guide

## Overview

This monorepo uses a centralized configuration system to maintain consistency across all packages while avoiding duplication. All shared configurations are defined once and referenced by individual packages.

## Configuration Architecture

```
money/
├── biome.json                    # Root Biome config (single source of truth)
├── packages/
│   ├── config/                   # Shared configuration package
│   │   ├── typescript/           # TypeScript configs
│   │   │   ├── base.json        # Base TS config with common settings
│   │   │   ├── bun.json         # Bun runtime config (extends base)
│   │   │   ├── node.json        # Node.js specific config (extends base)
│   │   │   └── react.json       # React specific config (extends base)
│   │   └── biome/
│   │       └── extend.json      # Helper for extending root biome config
│   └── [package-name]/
│       ├── biome.json           # Package-specific Biome config (extends root)
│       └── tsconfig.json        # Package-specific TS config (extends shared)
```

## How Configuration Inheritance Works

### Biome Configuration

1. **Root Config (`/biome.json`)**: Defines all formatting, linting, and organization rules for the entire monorepo
2. **Package Config (`/packages/*/biome.json`)**: Extends the root config using relative paths

```json
// packages/core/biome.json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "extends": ["../../biome.json"]
}
```

The package inherits ALL settings from root but can override specific rules if needed:

```json
// Example: Package with different line width requirement
{
  "extends": ["../../biome.json"],
  "formatter": {
    "lineWidth": 120  // Override root's 100 character limit
  }
}
```

### TypeScript Configuration

TypeScript configs use the `@money/config` package dependency to share settings:

1. **Base Config** (`@money/config/typescript/base.json`): Common compiler options for all TypeScript projects
2. **Variant Configs**: Extend base with specific settings
   - `bun.json`: Optimized for Bun runtime with ESNext modules
   - `node.json`: Adds Node.js types and libs
   - `react.json`: Adds DOM libs and JSX settings

```json
// packages/core/tsconfig.json
{
  "extends": "@money/config/typescript/bun.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

## Creating New Packages

### Step 1: Create Package Structure

```bash
mkdir -p packages/[package-name]/src
cd packages/[package-name]
```

### Step 2: Create package.json

```json
{
  "name": "@money/[package-name]",
  "version": "0.0.1",
  "private": true,
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "scripts": {
    "dev": "bun src/index.ts",
    "build": "tsc",
    "test": "bun test",
    "check": "biome check . --write",
    "format": "biome format . --write",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "@money/config": "workspace:*"
  }
}
```

### Step 3: Create biome.json

For standard packages that follow root conventions:

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "extends": ["../../biome.json"]
}
```

### Step 4: Create tsconfig.json

For Bun packages (recommended):

```json
{
  "extends": "@money/config/typescript/bun.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts", "**/*.spec.ts"]
}
```

For Node.js packages (if not using Bun):

```json
{
  "extends": "@money/config/typescript/node.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts", "**/*.spec.ts"]
}
```

For React packages:

```json
{
  "extends": "@money/config/typescript/react.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.tsx", "**/*.spec.tsx"]
}
```

### Step 5: Run Installation

```bash
bun install
```

## Creating New Apps

Apps follow the same pattern but may have additional configurations:

### For a Bun API (recommended):

```json
// apps/api/tsconfig.json
{
  "extends": "@money/config/typescript/bun.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist",
    "emitDecoratorMetadata": true,  // If using decorators
    "experimentalDecorators": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

### For a React App:

```json
// apps/web/tsconfig.json
{
  "extends": "@money/config/typescript/react.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist",
    "baseUrl": "./src",              // For absolute imports
    "paths": {
      "@/*": ["*"]
    }
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "**/*.test.tsx"]
}
```

## Configuration Precedence

1. **Most Specific Wins**: Package-level configs override shared configs
2. **Inheritance Chain**: 
   - TypeScript: package tsconfig → @money/config variant → @money/config base
   - Biome: package biome.json → root biome.json

## Adding New Shared Configurations

To add a new shared configuration type (e.g., ESLint, Prettier):

1. Add files to `packages/config/[tool-name]/`
2. Update `packages/config/package.json` exports:

```json
{
  "exports": {
    "./typescript/base.json": "./typescript/base.json",
    "./eslint": "./eslint/base.js",  // New export
    "./prettier": "./prettier/base.json"
  }
}
```

3. Reference in packages:

```javascript
// packages/core/.eslintrc.js
module.exports = {
  extends: [require.resolve('@money/config/eslint')]
}
```

## Best Practices

1. **Keep Root Configs Strict**: Define your strictest, most comprehensive rules at the root
2. **Override Sparingly**: Only override in packages when absolutely necessary
3. **Document Overrides**: Always comment why a package needs different settings
4. **Test Config Changes**: Run format/lint/typecheck after config changes
5. **Version Control**: Commit config changes separately from code changes

## Common Commands

```bash
# Run from monorepo root
bun run format        # Format all files using Biome
bun run lint          # Lint all files using Biome
bun run typecheck     # Type-check all packages with TypeScript

# Run for specific package
cd packages/[name]
bun run check         # Run Biome check and format
bun run typecheck     # Type-check this package only
```

## Troubleshooting

### Config not being picked up?
- Ensure `@money/config` is in `devDependencies`
- Run `bun install` after adding the dependency
- Check relative paths in extends statements

### TypeScript can't find @money/config?
- Make sure you're using `"extends": "@money/config/typescript/node.json"` (with quotes)
- Verify the config package is properly linked in workspaces

### Biome conflicts?
- Check if package has local overrides
- Verify extends path is correct (use relative path from package to root)
- Run `biome explain` to debug specific rules