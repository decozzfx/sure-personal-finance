# Repository Guidelines

## Build, Test, and Development Commands
- **Setup**: `cp .env.local.example .env.local && bin/setup` — install deps, set DB, prepare app.
- **Run app**: `bin/dev` — starts Rails server, Sidekiq, and Tailwind CSS watcher.
- **Rails console**: `bin/rails console`
- **Test all**: `bin/rails test` — run all Minitest tests
- **Test single file**: `bin/rails test test/models/user_test.rb` — run specific test file
- **Test single test**: `bin/rails test test/models/user_test.rb:42` — run specific test at line
- **System tests**: `bin/rails test:system` — use sparingly, they take longer
- **Lint Ruby**: `bin/rubocop` — style checks; `bin/rubocop -A` to auto-correct safe cops
- **Lint ERB**: `bundle exec erb_lint ./app/**/*.erb` — ERB template checks
- **Lint/fix JS**: `npm run lint` and `npm run lint:fix` — uses Biome
- **Format JS**: `npm run format` — Biome formatter
- **Security scan**: `bin/brakeman` — static analysis for Rails security issues

## Code Style & Naming Conventions

### Ruby
- **Indentation**: 2 spaces
- **Naming**: `snake_case` for methods/variables, `CamelCase` for classes/modules
- **File names**: Follow Rails conventions (e.g., `user.rb`, `accounts_controller.rb`)
- **Classes**: Prefer POROs and concerns over service objects; organize business logic in `app/models/`
- **Models**: Models should answer questions about themselves: `account.balance_series` not `AccountSeries.new(account).call`
- **Validations**: Simple validations (null, unique) in DB; complex validations in ActiveRecord

### Rails Conventions
- **Current context**: Use `Current.user` and `Current.family` (NOT `current_user`/`current_family`)
- **Migrations**: Inherit from `ActiveRecord::Migration[7.2]` (do NOT use 8.0 yet)
- **Controllers**: Skinny controllers, fat models
- **Queries**: Avoid N+1 queries; use `includes`/`joins` appropriately
- **Background jobs**: Sidekiq for async tasks (SyncJob, ImportJob, AssistantResponseJob)

### JavaScript & Stimulus
- **Naming**: `lowerCamelCase` for vars/functions, `PascalCase` for classes/components
- **Formatting**: Biome auto-formats code
- **Stimulus**: Use declarative actions in ERB (`data-action="click->toggle#toggle"`), NOT imperative event listeners in `connect()`
- **Controller size**: Keep lightweight (< 7 targets); use private methods, clear public API
- **Data passing**: Pass Rails data via `data-*-value` attributes
- **Component controllers**: In `app/components/` — only use within component templates
- **Global controllers**: In `app/javascript/controllers/` — reusable across views

### Views & Components
- **ERB**: Checked by `erb-lint`; avoid heavy logic in views
- **ViewComponents**: Use for complex logic/styling, reusability, variants, interactivity, accessibility
- **Partials**: Use for static HTML, simple template content, context-specific use cases
- **Icons**: Always use `icon` helper in `application_helper.rb`, NEVER `lucide_icon` directly
- **Styling**: Tailwind CSS v4.x; use design tokens (`text-primary`, `bg-container`) not raw colors
- **HTML**: Prefer semantic HTML (`<dialog>`, `<details>`) over JS components

### Frontend
- **Stack**: Hotwire (Turbo + Stimulus) for SPA-like UI without heavy JS
- **Turbo Frames**: For page sections over client-side solutions
- **State**: Query params for state, not localStorage/sessions
- **Formatting**: Server-side for currencies, numbers, dates; Stimulus for display only

## Testing Guidelines
- **Framework**: Minitest + fixtures (NEVER RSpec or FactoryBot)
- **Test files**: `*_test.rb` mirroring `app/` structure
- **Fixtures**: 2-3 per model for base cases; create edge cases inline
- **Stubs/mocks**: Use `mocha` gem; prefer `OpenStruct` for mock instances
- **VCR**: Use existing cassettes for HTTP requests
- **System tests**: Use sparingly (slow); prefer unit + focused integration tests
- **Quality**: Test critical paths only; distinguish commands (test called with params) vs queries (test output)

## Security & Configuration
- **Secrets**: Never commit; start from `.env.local.example`, use `.env.local` locally
- **Security**: Run `bin/brakeman` before major PRs
- **Auth**: Session-based for web; OAuth2 (Doorkeeper) + API keys for external `/api/v1/`
- **CSRF**: Protection enabled; strong params enforced

## Prohibited Actions
- Do NOT run `rails server`, `touch tmp/restart.txt`, `rails credentials`, or auto-run migrations

## Pre-PR Checklist
- Tests pass: `bin/rails test`
- Rubocop clean: `bin/rubocop -f github -a`
- ERB lint clean: `bundle exec erb_lint ./app/**/*.erb -a`
- Security clean: `bin/brakeman --no-pager`

## Key Architecture Notes
- **Modes**: "managed" or "self_hosted" via `Rails.application.config.app_mode`
- **Domain**: User → Accounts → Transactions → Categories/Tags/Rules
- **Multi-currency**: Store in base currency, use `Money` objects for conversion/formatting
- **Providers**: Plaid for bank sync; CSV import for manual data
