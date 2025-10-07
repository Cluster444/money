# Test Writing Guidelines

## Testing Philosophy

- **Test public APIs, not private implementation details**
- **Focus on behavior and outcomes, not internal structure**
- **Test concerns through their host classes (controllers/models)**, not in isolation
- **ApplicationController is private implementation** - test concerns through subclasses that have public routes

## Concern Testing Strategy

When testing concerns (like Authentication), test them **in the context of the classes that include them**. This includes concerns included in ApplicationController - test them through concrete controller subclasses that have actual routes:

```
# Good: Test authentication through UsersController
test/controllers/users_controller/authentication_test.rb

# Avoid: Testing concern in isolation
# test/models/concerns/authentication_test.rb
```

## Test Organization

- **Controller concerns**: Create subdirectory under `test/controllers/` for each controller that uses the concern
- **Model concerns**: Test through the models that include them
- **One test file per concern usage**, even if included in ApplicationController
- **ApplicationController concerns**: Always test through concrete controller subclasses with public routes, never ApplicationController itself

## Test Naming

- Use descriptive test names that explain the behavior: `test_should_redirect_unauthenticated_users_to_login`
- Follow Rails conventions: `test_should_[expected_behavior]_when_[condition]`

## What to Test

- **Controllers**: Response codes, redirects, session changes, template rendering
- **Models**: Validation, business logic, database interactions, callbacks
- **Concerns**: Only through their public interface in host classes

## What NOT to Test

- Private methods directly
- Internal concern implementation details
- Framework behavior (assume Rails works)
- Database schema (test through model behavior)

