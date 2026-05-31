# AGENTS

This is hostelz, a PMS for hostelz and more.

- be concise
- keep it technical
- keep README.md updated
- keen `.env*` files updated
- use `gleam check` for type-checking
- always run `gleam format`
- use `bun run test` for running tests
- use `bun run build` to compile everything

## Stack

- Bun
- Gleam
- Postgres

## Gleam

- follow DDD principles
- do not comment code unless its important
- illegal states unrepresentable
- use opaque types + smart constructors
- validate at the boundary, trust within
- use `Result` + types as proof of validation
- use named, exhaustive failure modes
- rely on sum-type errors + case
- aggregates as consistency boundaries
- modules + opacity + record update syntax
- linear top-to-bottom domain rules	`use <-` for guard chains

## Migrations

Use `bun db --help` to understand cli and follo these rules:

- `schema.sql` is the production schema
- never edit already commited migrations
- new feature migrations go into `current.sql`
- use only idempotent sql statements in migrations
- use `DO $$` when there's no `IF NOT EXISTS`
- review the migration befor commiting
- use `bun db watch --once` to apply `current.sql`
- commit `current.sql` using `bun db commit`
- review and validate the new `schema.sql`
- is should onlycontain changes derived from the migration
- when something goes wrong you can `bun db uncommit`
- write reverts in `current.sql` and start over