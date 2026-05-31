--! Previous: sha1:932db9825f887e00334b65ba62ec040425fb1043
--! Hash: sha1:2ee836accd565edfb648c261ace143e73d6287f6

-- Spaces: the bookable inventory tree. A space is either a unit (an atomic
-- sleepable leaf — bed, bunk, private room) or a grouping (room, dorm, cabin,
-- hostel, ...); `is_grouping` distinguishes them and `label` is the open-ended
-- name for the kind. The tree is an adjacency list: `parent_id` is a nullable
-- self-FK (NULL = root). Every space belongs to an organization.
--
-- Idempotent: IF NOT EXISTS everywhere, DO $$ for the FK constraints. New table,
-- no backfill. The "a unit cannot be a parent" and "child org = parent org"
-- rules are cross-row invariants enforced in the create-space use case.

create table if not exists spaces (
  id              text        primary key,
  organization_id text        not null,
  parent_id       text,
  is_grouping     boolean     not null,
  label           text        not null,
  name            text        not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'spaces_organization_id_fkey'
  ) then
    alter table spaces
      add constraint spaces_organization_id_fkey
      foreign key (organization_id) references organizations (id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'spaces_parent_id_fkey'
  ) then
    alter table spaces
      add constraint spaces_parent_id_fkey
      foreign key (parent_id) references spaces (id);
  end if;
end $$;

create index if not exists spaces_organization_id_idx on spaces (organization_id);
create index if not exists spaces_parent_id_idx on spaces (parent_id);
