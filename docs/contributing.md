# Contributing

## Development Setup

1. Clone the repository:

```bash
git clone https://github.com/tailscope/tailscope.git
cd tailscope
```

2. Install Ruby dependencies:

```bash
bundle install
```

3. Install frontend dependencies and build:

```bash
cd client
npm install
npm run build
cd ..
```

4. Run the test suite:

```bash
bundle exec rspec
```

## Project Structure

```
tailscope/
├── lib/tailscope/          # Core Ruby library
│   ├── configuration.rb    # Configuration management
│   ├── database.rb         # SQLite connection
│   ├── schema.rb           # Table definitions
│   ├── storage.rb          # Async data storage
│   ├── source_locator.rb   # Backtrace resolution
│   ├── issue_builder.rb    # Issue aggregation
│   ├── code_analyzer.rb    # Static analysis
│   ├── cli.rb              # Thor CLI
│   ├── engine.rb           # Rails engine
│   ├── railtie.rb          # Rails integration
│   ├── middleware/          # Rack middleware
│   ├── subscribers/        # ActiveSupport subscribers
│   ├── detectors/          # Detection algorithms
│   └── debugger/           # Interactive debugger
├── app/controllers/        # API controllers
├── config/routes.rb        # API routes
├── client/                 # React frontend (Vite + Tailwind)
├── spec/                   # RSpec test suite
│   ├── tailscope/          # Unit specs for lib classes
│   ├── controllers/        # Request specs for API
│   ├── dummy/              # Minimal Rails app for testing
│   └── spec_helper.rb      # Test configuration
└── public/                 # Built frontend assets
```

## Running Tests

```bash
# Full suite
bundle exec rspec

# Specific file
bundle exec rspec spec/tailscope/storage_spec.rb

# Specific test
bundle exec rspec spec/tailscope/storage_spec.rb:15
```

## Mutation Testing

Tailscope uses [mutant](https://github.com/mbj/mutant) for mutation testing to verify test quality:

```bash
bundle exec mutant run
```

The configuration is in `.mutant.yml`. Mutant modifies source code systematically and checks that at least one test fails for each modification, ensuring tests actually verify behavior rather than just exercising code.

## Frontend Development

The frontend is a React SPA in the `client/` directory.

```bash
cd client

# Development build with watch
npm run dev

# Production build (outputs to ../public/)
npm run build
```

After making frontend changes, run `npm run build` to update the compiled assets in `public/`.

## Code Style

- Ruby: Standard Ruby style. No rubocop config (yet), but follow existing patterns.
- JavaScript: Standard React patterns. Functional components with hooks.
- Tests: RSpec with request specs for controllers, unit specs for library code.

## Test Structure

**Unit specs** (`spec/tailscope/`): Test individual classes in isolation. Use mocks/stubs for dependencies.

**Request specs** (`spec/controllers/`): Test API endpoints through HTTP via a minimal Rails dummy app. Use `type: :request` and make HTTP calls (`get`, `post`, `delete`).

**Dummy app** (`spec/dummy/`): Minimal Rails application that mounts the Tailscope engine. Used by request specs to test the full request/response cycle.

## Adding a New Detector

1. Create the detector module in `lib/tailscope/detectors/`
2. Hook it into the appropriate lifecycle point (subscriber, middleware, or IssueBuilder)
3. Add issue generation in `IssueBuilder` if it produces aggregated issues
4. Write specs covering the detection logic
5. Add a section to `docs/detectors.md`

## Adding a New API Endpoint

1. Add the route in `config/routes.rb`
2. Create or update the controller in `app/controllers/tailscope/api/`
3. Write request specs in `spec/controllers/`
4. Update the React frontend if the endpoint serves the dashboard
5. Document the endpoint in `docs/api.md`

## Adding a Code Smell Rule

1. Add the detection method in `lib/tailscope/code_analyzer.rb`
2. Call it from the appropriate `analyze_*` method
3. Use `build_issue` to create the issue struct with severity, description, and suggested fix
4. Write specs
5. Document the rule in `docs/code-analysis.md`

## Commit Guidelines

- Write clear, descriptive commit messages
- One logical change per commit
- Reference issues when applicable

## Releasing

1. Update `lib/tailscope/version.rb`
2. Update CHANGELOG
3. Build and push the gem:

```bash
gem build tailscope.gemspec
gem push tailscope-X.Y.Z.gem
```
