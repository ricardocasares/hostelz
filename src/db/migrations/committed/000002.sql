--! Previous: sha1:959a200f85bfbd67b0aed0dd272cfe7bc873b61c
--! Hash: sha1:932db9825f887e00334b65ba62ec040425fb1043

-- Organizations (tenants that own guests) and users (system accounts), plus the
-- guest relationships: every guest belongs to an organization (mandatory), and
-- may be linked to a user account (optional — walk-ins are not).
--
-- Idempotent: IF NOT EXISTS everywhere, DO $$ for the FK constraints (no
-- IF NOT EXISTS form). A seeded default org backfills any pre-existing guests
-- before the NOT NULL/FK is added; user_id is nullable so walk-ins need none.

create table if not exists organizations (
  id         text        primary key,
  slug       text        not null,
  name       text        not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists organizations_slug_key on organizations (slug);

insert into organizations (id, slug, name)
values ('org_default', 'default', 'Default')
on conflict (id) do nothing;

create table if not exists users (
  id         text        primary key,
  email      text        not null,
  name       text        not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists users_email_key on users (email);

alter table guests add column if not exists organization_id text;
update guests set organization_id = 'org_default' where organization_id is null;
alter table guests alter column organization_id set not null;

alter table guests add column if not exists user_id text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'guests_organization_id_fkey'
  ) then
    alter table guests
      add constraint guests_organization_id_fkey
      foreign key (organization_id) references organizations (id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'guests_user_id_fkey'
  ) then
    alter table guests
      add constraint guests_user_id_fkey
      foreign key (user_id) references users (id);
  end if;
end $$;

create index if not exists guests_organization_id_idx on guests (organization_id);
create index if not exists guests_user_id_idx on guests (user_id);
