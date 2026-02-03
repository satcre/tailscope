# Code Analysis

Tailscope includes a static code analyzer that scans Ruby files in your `app/` directory for common code smells, security issues, and architectural problems. Each detected issue includes a severity level and a specific suggested fix.

Code analysis runs on-demand when the Issues page is loaded. It does not run during request processing and has no runtime overhead.

---

## Model Detectors

| Rule | Severity | Description |
|------|----------|-------------|
| [Missing Validations](#missing-validations) | Warning | Models without any validation declarations |
| [Fat Model](#fat-model) | Warning | Models mixing 3+ concerns |
| [Callback Abuse](#callback-abuse) | Warning | Models with 4+ lifecycle callbacks |

### Missing Validations

Flags ActiveRecord models that inherit from `ApplicationRecord` but have no `validates`, `validate`, or `has_secure_password` declarations.

**Detected when:**
- Class inherits from `ApplicationRecord`
- No validation keywords found anywhere in the file

> **Fix:** Add presence validations for required fields, especially `belongs_to` associations.

### Fat Model

Flags models that mix 3+ concerns: callbacks, presentation logic, query logic, and external service calls.

**Concern types detected:**
- **Callbacks:** `before_save`, `after_create`, etc.
- **Presentation:** methods named `display_*`, `format_*`, `to_csv`, `to_pdf`
- **Query logic:** 3+ class methods or `scope` declarations
- **External services:** references to Mailer, HTTParty, Faraday, RestClient, etc.

> **Fix:** Extract concerns into focused classes (presenters, services, query objects, concerns).

### Callback Abuse

Flags models with 4 or more lifecycle callbacks. Excessive callbacks create hidden control flow and make debugging difficult.

> **Fix:** Move side-effect callbacks into explicit service objects called from controllers.

---

## Controller Detectors

| Rule | Severity | Description |
|------|----------|-------------|
| [Missing Authentication](#missing-authentication) | Warning | No `before_action` for auth |
| [Unsafe Params](#unsafe-params) | Warning | Direct `params[:key]` access without strong params |
| [Data Exposure](#data-exposure) | Critical | Rendering full models as JSON |
| [Direct SQL](#direct-sql) | Warning | Raw SQL usage patterns |
| [Fat Controller Actions](#fat-controller-actions) | Warning | Actions longer than 15 lines |
| [Multiple Responsibilities](#multiple-responsibilities) | Warning | Querying 3+ model classes |

### Missing Authentication

Flags controllers that have no `before_action` for authentication or authorization.

**Detected when:**
- Class inherits from a controller (not `ApplicationController` itself)
- No `before_action` referencing `authenticate`, `authorize`, `require_login`, `require_admin`, or `ensure_authenticated`

> **Fix:** Add a `before_action :authenticate_user!` or equivalent.

### Unsafe Params

Flags direct `params[:key]` or `params.dig(:key)` access without strong parameters.

**Exceptions (not flagged):**
- Lines with `.permit`
- Access to `:page`, `:id`, `:format` (common safe params)
- Files that define a `*_params` method using `.permit`

> **Fix:** Create a private `*_params` method with `params.require(:resource).permit(:field1, :field2)`.

### Data Exposure

Flags `render json: @variable` without `:only`, `:except`, `:serializer`, `as_json`, or `to_json` -- which exposes all database columns including potentially sensitive fields.

> **Fix:** Use `as_json(only: [:id, :name])` or create a serializer.

### Direct SQL

Flags raw SQL usage patterns:

- `Arel.sql(...)` calls
- `find_by_sql(...)` calls
- SQL functions in `.order()` (`RANDOM`, `RAND`, `LENGTH`)
- Raw SQL strings in `.where()` containing `SELECT`/`INSERT`/`UPDATE`/`DELETE`

> **Fix:** Replace with ActiveRecord query methods for safety and portability.

### Fat Controller Actions

Flags controller actions longer than 15 lines. Controllers should only handle request/response flow.

> **Fix:** Extract business logic into service objects.

### Multiple Responsibilities

Flags controllers that directly query 3 or more different model classes, suggesting the controller handles too many concerns (SRP violation).

> **Fix:** Extract into a query object, presenter, or dashboard object.

---

## General Detectors

These run on all Ruby files under `app/`.

| Rule | Severity | Description |
|------|----------|-------------|
| [Long Methods](#long-methods) | Info | Methods longer than 20 non-blank lines |
| [Long Classes](#long-classes) | Warning | Classes exceeding line thresholds |
| [TODO/FIXME Comments](#todofixme-comments) | Info | Unresolved TODO/FIXME/HACK comments |
| [Hardcoded Secrets](#hardcoded-secrets) | Critical | String literals assigned to secret-named variables |
| [Empty Rescue Blocks](#empty-rescue-blocks) | Warning | Silently swallowed exceptions |
| [Law of Demeter Violations](#law-of-demeter-violations) | Info | Method chains with 3+ dots |

### Long Methods

Flags methods longer than 20 non-blank lines.

> **Fix:** Break into smaller methods with descriptive names.

### Long Classes

Flags classes exceeding a line threshold:

| Class type | Threshold |
|------------|-----------|
| Models | 80 non-blank lines |
| All other classes | 120 non-blank lines |

> **Fix:** Extract groups of related methods into concerns, services, or separate classes.

### TODO/FIXME Comments

Flags `TODO`, `FIXME`, and `HACK` comments in source code.

> **Fix:** Either fix the issue or create a tracked ticket. Add a reference (e.g., `TODO: [JIRA-123]`) so it's traceable.

### Hardcoded Secrets

Flags lines that assign string literals to variables named `*SECRET*`, `*PASSWORD*`, `*API_KEY*`, `*TOKEN*`, or `*PRIVATE_KEY*`.

**Exceptions (not flagged):**
- Lines using `ENV[...]`, `ENV.fetch(...)`, or `Rails.application.credentials`
- Comment lines

> **Fix:** Use environment variables or Rails credentials.

### Empty Rescue Blocks

Flags `rescue` blocks where the next meaningful line is `end` -- meaning the exception is silently swallowed.

> **Fix:** At minimum, log the error. Preferably re-raise or handle explicitly.

### Law of Demeter Violations

Flags method chains with 3+ dots (e.g., `user.company.address.city`).

**Excluded chains:**
- ActiveRecord query chains (`.where`, `.select`, `.order`, etc.)
- Chains starting with `Rails.`
- Type conversion chains (`.to_s.`, etc.)

> **Fix:** Add `delegate` declarations or wrapper methods to reduce coupling.

---

## Fingerprinting

Each code smell issue gets a unique fingerprint based on:

| Component | Purpose |
|-----------|---------|
| Issue type | `code_smell` |
| Title | Identifies the specific rule |
| Source file | Ties the issue to a location |
| Source line | Provides exact position |

This allows the ignore/unignore feature to persist across analysis runs, as long as the issue hasn't moved to a different line.

---

## Limitations

- Analysis is **line-based**, not AST-based. Some patterns may produce false positives.
- Only scans files under `app/`. Library code, gems, and config files are not analyzed.
- Detection runs synchronously on the web request that loads the Issues page. For very large codebases, this may add noticeable latency to the first page load.
