# hostelz

A property management system (PMS) for hostels and more.

## Stack

- **Bun** — runtime, bundler, test runner
- **Gleam** — domain and application logic, compiled to JavaScript
- **Postgres** — persistence (`graphile-migrate` migrations, `bun-squirrel` typed queries)
- **Vite** — frontend build (Gleam compiled via `vite-gleam`)
- **Vercel** — deploy

The Gleam toolchain is provided through npm (`@chouquette/gleam`) and installed by `bun install` — no separate Gleam install needed.

## Architecture

DDD layering under `src/`:

- `domain/` — entities, value objects, and ports (opaque types + smart constructors; illegal states unrepresentable)
- `app/` — use cases that orchestrate the domain
- `db/` — Postgres adapters, squirrel-generated SQL, migrations, and `schema.sql`
- `router/` — HTTP routing, request context, replies
- `api.gleam` / `api.ts` — server entry (a Bun `fetch` handler)

## Setup

```sh
bun install
cp .env.sample .env.local   # set DATABASE_URL, ROOT_DATABASE_URL, SHADOW_DATABASE_URL
bun db migrate              # apply migrations to the dev DB
```

Env files:

- `.env.sample` — template (committed)
- `.env.local` — your dev values (gitignored)
- `.env.test` — test DB config, no secrets (committed)

## Development

```sh
bun dev        # api (watch) + gleam test (watch) + vite, concurrently
```

Individually: `bun dev:api`, `bun dev:vite`, `bun dev:test`.

Type-check with `gleam check`; format with `gleam format`.

## Testing

```sh
bun run test   # migrate the test DB (.env.test), then run the Gleam suite
```

Requires a reachable Postgres — integration tests round-trip against `hostelix_test`.

## Build

```sh
bun run build  # build:db (migrate) + build:vite + build:gleam + build:api
```

`build:vite` compiles the frontend (and Gleam); `build:api` bundles `src/api.ts` to `api/index.js`.

## Migrations

Managed with `graphile-migrate` via `bun db` (`bun db --help`):

- `src/db/schema.sql` — production schema (generated; do not hand-edit)
- `src/db/migrations/current.sql` — work-in-progress migration (idempotent SQL only)
- `bun db watch --once` — apply `current.sql`
- `bun db commit` — promote `current.sql` to a numbered migration
- `bun db uncommit` — undo the last commit

## Deploy

Deployed on Vercel (`vercel.json`): `/api/*` is served by the bundled `src/api.ts`; everything else by the Vite build.

## CI

`.github/workflows/build.yml` runs on pushes to `main` and on PRs — installs deps, runs the test suite against a Postgres service, checks formatting, and builds the app (minus the migrate step).
