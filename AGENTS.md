# Agent Development Guide

**Note**: This project uses [bd (beads)](https://github.com/steveyegge/beads)
for issue tracking. Use `bd` commands instead of markdown TODOs.
See BEADS.md for workflow details.

## Build/Test/Lint Commands
```bash
# Run all tests
bin/rails test
# Run specific test file
bin/rails test test/models/user_test.rb
# Run specific test method
bin/rails test test/models/user_test.rb -n test_should_be_valid
# Run system tests
bin/rails test:system
# Run linting
bin/rubocop
# Run security scan
bin/brakeman
# Check JavaScript dependencies
bin/importmap audit
# Setup database
bin/rails db:setup
# Start development server
bin/dev
# Run Ruby code in Rails context (for debugging)
bin/rails runner "puts User.count"
# Avoid using bin/rails console - it's meant for interactive REPL only
```

## Code Style Guidelines

- **Ruby Style**: Follow `rubocop-rails-omakase` conventions (configured in `.rubocop.yml`)
- **Indentation**: 2 spaces (no tabs)
- **Quotes**: Use double quotes for strings
- **Naming**: snake_case for variables/methods, CamelCase for classes
- **Imports**: Use relative paths for internal requires
- **Error Handling**: Use Rails conventions, avoid rescuing Exception
- **Testing**: Use Rails default testing framework (not RSpec)
- **Database**: SQLite3 for development/test, follow Rails migration patterns

## Project Structure

- Rails 8.0.3 application with import maps
- Authentication system using bcrypt
- Background jobs via solid_queue
- Caching via solid_cache
- WebSocket via solid_cable
- Deployment via Kamal
