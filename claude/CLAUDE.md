## Global Instructions

- When uncertain, ask one clarifying question instead of assuming.
- Use README.md as the project knowledge source; update it with any new features or changes.
- When investigating code, check internal libs (e.g. `se.nordnet`) for shared utilities.
- Use TDD when applicable. Review and simplify after changes.
- Avoid em dash in output.
- Prefer smaller blast radius. When a change could cascade widely, propose the minimal scope first and let the user decide to expand.

## Java

**Style**: Import specific classes (no `*`, no fully-qualified names). No `var`. Follow SonarLint suggestions.

**Types**: Prefer records with `@Builder`. No lombok `@Constructor` -- use explicit constructors. Return `Optional` instead of null. Use `orElseThrow()` not `get()`. Avoid `java.sql.Date` -- use `rs.getObject("date", LocalDate.class)`. Use text blocks for multi-line strings.

**Database**: Prefer `jdbcClient` over `jdbcTemplate`. With PostgreSQL JDBC 42.7+, use `.query(Instant.class)` directly for TIMESTAMPTZ columns. Prefer virtual threads for blocking operations.

**Spring**: Prefer constructor value injection.

**Testing**: Use `mvn` (not `mvnw`). Use assertj for assertions. Always add unit + integration tests (SpringBoot/application test). Test through public API only -- never change access modifiers for tests. Use existing prod SQL and repos/services for test data (not test-only SQL or direct SQL). Use `OutputCaptureExtension` for log verification. Fix docker env for tests that need it; warn if not fixable. After adding new tests, review existing tests for overlap. Merge tests that cover subsets of the same scenario. Prefer fewer comprehensive tests over many narrow ones. Parameterize where possible.

## Refactoring

- When renaming: only rename what was explicitly requested. Don't cascade renames to unrelated code.
- When suggesting names: provide 2-3 candidates with brief rationale. Don't apply without approval.
- Prefer descriptive method names over generic ones (e.g., `groupByInstrumentAndSide` over `buildMap`).

## Frontend

- Prefer TypeScript over JavaScript.
- In webapp-next and monorepo-admin, prefer Nordnet Tailwind UI components (https://ui.prod.nntech.io/ui-tailwind/?path=/docs/design-system-1-intro--docs).
- Verify webapp runs after changes with no runtime errors.
- For monorepo-admins: run `npx nx test <project-name>` after changes. Update mocked API endpoints when changing API client or backend API.

## Workflow

- After implementing a feature, offer to run `/simplify` on staged changes.
- When reviewing, check for: duplicated tests, missing integration tests, unused imports, naming consistency.
