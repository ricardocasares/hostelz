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

Aggregates: **Organization** (a tenant; has a unique URL `slug`), **User** (a system account; unique email), **Guest**, and **Space**. A guest **belongs to an organization** (mandatory) and **may be linked to a user** (optional — walk-ins have no account). A **Space** is the bookable inventory: a tree (adjacency list via a nullable `parent_id`) of either a `unit` (an atomic sleepable leaf — bed, bunk, private room) or a `grouping` (room, dorm, cabin, hostel, …); both carry a free-form `label`. Any space is bookable; only a grouping may contain children. Each aggregate holds the other's id as a value object, never the whole aggregate. (Bookings/availability are not built yet.)

## HTTP API

All routes are under `/api`. Bodies and responses are JSON; ids are server-minted.

| Method & path | Body | Notes |
| --- | --- | --- |
| `POST /organizations` | `{name, slug}` | 201; 409 if the slug is taken, 422 if invalid |
| `GET /organizations` | — | list, newest first |
| `GET /organizations/:id` | — | one, or 404 |
| `POST /users` | `{email, name}` | 201; 409 if the email is taken |
| `GET /users` · `GET /users/:id` | — | list / one |
| `POST /organizations/:org_id/guests` | `{name, email, user_id?}` | 201; `user_id` optional (omit for a walk-in); 404 if the org or user is unknown |
| `GET /organizations/:org_id/guests` | — | the org's guests |
| `GET /guests/:id` | — | one, or 404 |
| `POST /organizations/:org_id/spaces` | `{name, kind, label, parent_id?}` | 201; `kind` is `"unit"`/`"grouping"`; omit `parent_id` for a root; 404 unknown org/parent; 422 if the parent is a unit (can't contain children) |
| `GET /organizations/:org_id/spaces` | — | the org's spaces (flat; build the tree from `parent_id`) |
| `GET /spaces/:id` · `GET /spaces/:id/children` | — | one / its direct children |

Slug uniqueness and email uniqueness are enforced by database unique indexes (surfaced as `409`), not read-then-write checks.

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
