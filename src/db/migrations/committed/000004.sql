--! Previous: sha1:2ee836accd565edfb648c261ace143e73d6287f6
--! Hash: sha1:bdb68e8ef7d409ed98c490ef35c733d8dd52f4c2

-- Authentication & authorization tables.
--
-- user_credentials: a user's argon2id password hash (separate from identity).
-- sessions: revocable Bearer sessions; only sha256(token) is stored, expiry in SQL.
-- roles + role_permissions: per-org roles composed from the code permission catalog.
-- memberships: user↔org join, one role each, unique per (org, user).
--
-- Idempotent (IF NOT EXISTS; inline FKs). role_permissions cascade-delete with
-- their role; a role still referenced by a membership cannot be deleted (the FK
-- blocks it, surfaced as a conflict).

create table if not exists user_credentials (
  user_id       text        primary key references users (id),
  password_hash text        not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists sessions (
  token_hash text        primary key,
  user_id    text        not null references users (id),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists sessions_user_id_idx on sessions (user_id);

create table if not exists roles (
  id              text        primary key,
  organization_id text        not null references organizations (id),
  name            text        not null,
  is_owner        boolean     not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index if not exists roles_org_name_key on roles (organization_id, name);

create table if not exists role_permissions (
  role_id    text not null references roles (id) on delete cascade,
  permission text not null,
  primary key (role_id, permission)
);

create table if not exists memberships (
  id              text        primary key,
  organization_id text        not null references organizations (id),
  user_id         text        not null references users (id),
  role_id         text        not null references roles (id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index if not exists memberships_org_user_key on memberships (organization_id, user_id);
create index if not exists memberships_user_id_idx on memberships (user_id);
