--! Previous: -
--! Hash: sha1:959a200f85bfbd67b0aed0dd272cfe7bc873b61c

-- Guests: people who stay at a property.
--
-- `id` is text (app-generated) to match the domain's `GuestId`, which wraps a
-- String. Name and email are stored as plain text — validation lives in the
-- domain (smart constructors), not the schema. Timestamps default to now();
-- the repo bumps `updated_at` on upsert.
create table if not exists guests (
  id         text        primary key,
  name       text        not null,
  email      text        not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
