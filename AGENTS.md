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
- Framework: Minitest (Rails). Name files `*_test.rb` and mirror `app/` structure.
- Run: `bin/rails test` locally and ensure green before pushing.
- Fixtures/VCR: Use `test/fixtures` and existing VCR cassettes for HTTP. Prefer unit tests plus focused integration tests.

## Commit & Pull Request Guidelines
- Commits: Imperative subject ≤ 72 chars (e.g., "Add account balance validation"). Include rationale in body and reference issues (`#123`).
- PRs: Clear description, linked issues, screenshots for UI changes, and migration notes if applicable. Ensure CI passes, tests added/updated, and `rubocop`/Biome are clean.

## Security & Configuration Tips
- Never commit secrets. Start from `.env.local.example`; use `.env.local` for development only.
- Run `bin/brakeman` before major PRs. Prefer environment variables over hard-coded values.

## API Development Guidelines

### OpenAPI Documentation (MANDATORY)
When adding or modifying API endpoints in `app/controllers/api/v1/`, you **MUST** create or update corresponding OpenAPI request specs for **DOCUMENTATION ONLY**:

1. **Location**: `spec/requests/api/v1/{resource}_spec.rb`
2. **Framework**: RSpec with rswag for OpenAPI generation
3. **Schemas**: Define reusable schemas in `spec/swagger_helper.rb`
4. **Generated Docs**: `docs/api/openapi.yaml`
5. **Regenerate**: Run `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize` after changes

### Post-commit API consistency (LLM checklist)
After every API endpoint commit, ensure: (1) **Minitest** behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb` (no behavioral assertions in rswag); (2) **rswag** remains docs-only (no `expect`/`assert_*` in `spec/requests/api/v1/`); (3) **rswag auth** uses the same API key pattern everywhere (`X-Api-Key`, not OAuth/Bearer). Full checklist: [.cursor/rules/api-endpoint-consistency.mdc](.cursor/rules/api-endpoint-consistency.mdc).

## Providers: Pending Transactions and FX Metadata (SimpleFIN/Plaid/Lunchflow)

- Pending detection
  - SimpleFIN: pending when provider sends `pending: true`, or when `posted` is blank/0 and `transacted_at` is present.
  - Plaid: pending when Plaid sends `pending: true` (stored at `transaction.extra["plaid"]["pending"]` for bank/credit transactions imported via `PlaidEntry::Processor`).
  - Lunchflow: pending when API returns `isPending: true` in transaction response (stored at `transaction.extra["lunchflow"]["pending"]`).
- Storage (extras)
  - Provider metadata lives on `Transaction#extra`, namespaced (e.g., `extra["simplefin"]["pending"]`).
  - SimpleFIN FX: `extra["simplefin"]["fx_from"]`, `extra["simplefin"]["fx_date"]`.
- UI
  - Shows a small “Pending” badge when `transaction.pending?` is true.
- Variability
  - Some providers don’t expose pendings; in that case nothing is shown.
- Configuration (default-off)
  - SimpleFIN runtime toggles live in `config/initializers/simplefin.rb` via `Rails.configuration.x.simplefin.*`.
  - Lunchflow runtime toggles live in `config/initializers/lunchflow.rb` via `Rails.configuration.x.lunchflow.*`.
  - ENV-backed keys:
    - `SIMPLEFIN_INCLUDE_PENDING=1` (forces `pending=1` on SimpleFIN fetches when caller didn’t specify a `pending:` arg)
    - `SIMPLEFIN_DEBUG_RAW=1` (logs raw payload returned by SimpleFIN)
    - `LUNCHFLOW_INCLUDE_PENDING=1` (forces `include_pending=true` on Lunchflow API requests)
    - `LUNCHFLOW_DEBUG_RAW=1` (logs raw payload returned by Lunchflow)

### Provider support notes

- SimpleFIN: supports pending + FX metadata; stored under `extra["simplefin"]`.
- Plaid: supports pending when the upstream Plaid payload includes `pending: true`; stored under `extra["plaid"]`.
- Plaid investments: investment transactions currently do not store pending metadata.
- Lunchflow: supports pending via `include_pending` query parameter; stored under `extra["lunchflow"]`.
- Manual/CSV imports: no pending concept.
