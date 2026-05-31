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

Aggregates: **Organization** (a tenant; unique URL `slug`), **User** (a system account; unique email, argon2id password in a separate `user_credentials`), **Guest**, **Space**, plus the authz aggregates **Role** and **Membership**. A guest **belongs to an organization** (mandatory) and **may be linked to a user** (optional — walk-ins have no account). A **Space** is the bookable inventory: a tree (adjacency list via a nullable `parent_id`) of either a `unit` (an atomic sleepable leaf — bed, bunk, private room) or a `grouping` (room, dorm, cabin, hostel, …); both carry a free-form `label`. Any space is bookable; only a grouping may contain children. Each aggregate holds the other's id as a value object, never the whole aggregate. (Bookings/availability are not built yet.)

## Authentication & authorization

- **Authentication** is a single middleware (`router/guard.require_auth`): `POST /api/auth/register` + `POST /api/auth/login` are public; every other route requires `Authorization: Bearer <token>`. Login returns an opaque token; only its `sha256` is stored in `sessions` (revocable, 30-day expiry in SQL).
- **Authorization** is **permission-based RBAC**. Routes check a `Permission` (a code-defined catalog of fine-grained `resource:action` values), never a role name. **Roles are per-org data** (`roles` + `role_permissions`); a **Membership** gives a user exactly one role per org. Creating an org seeds a single system **Owner** role (implicitly all permissions, immutable) for the creator; other roles are created by the org and assigned to members. The `require_permission` seam reserves room for per-resource scoping later.

## HTTP API

All routes are under `/api`. Bodies and responses are JSON; ids are server-minted. Except `register`/`login`, every route needs a Bearer token (`401` if missing/invalid); org-scoped routes also need the matching permission (`403` otherwise).

| Method & path | Body | Permission / notes |
| --- | --- | --- |
| `POST /auth/register` | `{email, name, password}` | public; 201; 409 email taken; 422 short password (min 8) |
| `POST /auth/login` | `{email, password}` | public; 200 `{token, user}`; 401 on bad creds |
| `POST /auth/logout` · `GET /auth/me` | — | any authenticated user |
| `POST /organizations` | `{name, slug}` | authenticated → creator becomes **Owner**; 409 slug taken |
| `GET /organizations` | — | the caller's organizations |
| `GET /organizations/:id` | — | `org:read` |
| `GET/POST /organizations/:id/roles`, `PUT/DELETE …/roles/:rid` | `{name, permissions[]}` | `role:read`/`create`/`update`/`delete`; the Owner role can't be edited/deleted |
| `GET/POST /organizations/:id/members`, `PUT/DELETE …/members/:uid` | `{email, role_id}` / `{role_id}` | `member:read`/`create`/`update`/`delete`; last-Owner removal/demotion refused |
| `GET/POST /organizations/:id/guests` | `{name, email, user_id?}` | `guest:read` / `guest:create` |
| `GET /guests/:id` | — | `guest:read` on its org |
| `GET/POST /organizations/:id/spaces` | `{name, kind, label, parent_id?}` | `space:read` / `space:create` |
| `GET /spaces/:id` · `/children` | — | `space:read` on its org |

Slug and email uniqueness are enforced by database unique indexes (surfaced as `409`), not read-then-write checks.

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

## Logging

Structured logging goes through a small `log` abstraction (`src/log.gleam`) with a built-in writer (`src/logging.gleam`); handlers depend only on `log`, so the backend is swappable. Configured from env:

- `LOG_ENABLED` — `true` (default) / `false` (disables all output)
- `LOG_LEVEL` — `debug` | `info` (default) | `warn` | `error`
- `LOG_FORMAT` — `json` (default) | `text`

Each request gets a `request_id` (from an inbound `X-Request-Id` header, else generated and echoed back), and the logger handed to handlers is pre-bound with `request_id`/`method`/`path`. Handlers add fields with `log.with(deps.logger, [log.string("k", v)])` then `log.info(_, "…")`.

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
