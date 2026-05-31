--! Previous: sha1:bdb68e8ef7d409ed98c490ef35c733d8dd52f4c2
--! Hash: sha1:8d111e085d4865b517e35cbd009d378d5a4ceddc

-- Bookings: a Booking (aggregate root) holds one or more BookingItems. Each item
-- claims space for a nightly period [check_in, check_out). An item is either
-- pinned to a specific node (a bed, or a room/floor booked whole) or an
-- unassigned hold against a one-level room-type (the physical bed is chosen at
-- check-in). booking_demand materializes demand: a pinned item expands to
-- {node} + descendants as is_pin rows (a partial EXCLUDE forbids overlapping
-- pins on the same node); an unassigned hold is a single is_pin=false row on the
-- room-type. Oversell is bounded by a capacity count (demand <= bookable leaf
-- children) enforced by the create use case under a per-org advisory lock.
--
-- Also adds owner-controlled bookability to spaces (units default bookable,
-- groupings not). Idempotent: IF NOT EXISTS, inline FKs on new tables, DO $$
-- guards for the not-null backfill and the partial EXCLUDE (no IF NOT EXISTS
-- form).

create extension if not exists btree_gist;

-- spaces.bookable -----------------------------------------------------------
alter table spaces add column if not exists bookable boolean;
update spaces set bookable = not is_grouping where bookable is null;
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'spaces'
      and column_name = 'bookable'
      and is_nullable = 'YES'
  ) then
    alter table spaces alter column bookable set not null;
  end if;
end $$;

-- bookings ------------------------------------------------------------------
create table if not exists bookings (
  id              text        primary key,
  organization_id text        not null references organizations (id),
  guest_id        text        references guests (id),
  status          text        not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists bookings_organization_id_idx on bookings (organization_id);
create index if not exists bookings_guest_id_idx on bookings (guest_id);

-- booking_items -------------------------------------------------------------
create table if not exists booking_items (
  id                text        primary key,
  booking_id        text        not null references bookings (id) on delete cascade,
  period            daterange   not null,
  kind              text        not null,
  target_space_id   text        not null references spaces (id),
  assigned_space_id text        references spaces (id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint booking_items_period_not_empty check (not isempty(period))
);
create index if not exists booking_items_booking_id_idx on booking_items (booking_id);

-- booking_demand ------------------------------------------------------------
-- Pinned rows (is_pin) materialize an assigned item's {node}+descendants; the
-- partial EXCLUDE makes two overlapping pins on the same node impossible. Hold
-- rows (not is_pin) are a single row on the room-type, counted against capacity.
create table if not exists booking_demand (
  booking_item_id text      not null references booking_items (id) on delete cascade,
  space_id        text      not null references spaces (id),
  period          daterange not null,
  is_pin          boolean   not null
);
create index if not exists booking_demand_space_id_idx on booking_demand (space_id);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'booking_demand_no_overlap'
  ) then
    alter table booking_demand
      add constraint booking_demand_no_overlap
      exclude using gist (space_id with =, period with &&) where (is_pin);
  end if;
end $$;
