//// This module contains the code to run the sql queries defined in
//// `./src/db/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import brioche/sql
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/option.{type Option}
import gleam/string
import gleam/time/calendar.{type Date}

/// Assign an unassigned item to a specific bed: delete its hold demand, set the
/// item's assigned space, and pin the bed for the same period. The partial
/// EXCLUDE rejects the pin if the bed is already taken for an overlapping period.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn assign_booking_item(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Assign an unassigned item to a specific bed: delete its hold demand, set the
-- item's assigned space, and pin the bed for the same period. The partial
-- EXCLUDE rejects the pin if the bed is already taken for an overlapping period.
with removed as (
  delete from booking_demand
  where booking_item_id = $1 and is_pin = false
  returning period
),
updated as (
  update booking_items
  set assigned_space_id = $2, updated_at = now()
  where id = $1
)
insert into booking_demand (booking_item_id, space_id, period, is_pin)
select $1, $2, removed.period, true
from removed;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `count_organization_owners` query
/// defined in `./src/db/sql/count_organization_owners.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CountOrganizationOwnersRow {
  CountOrganizationOwnersRow(owners: Int)
}

/// How many members of an organization hold an owner role (for the last-owner
/// guard). Cast to int so it decodes as a plain integer.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn count_organization_owners(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(CountOrganizationOwnersRow), sql.SqlError),
) {
  let decoder = {
    use owners <- decode.field(0, int_decoder())
    decode.success(CountOrganizationOwnersRow(owners:))
  }

  "-- How many members of an organization hold an owner role (for the last-owner
-- guard). Cast to int so it decodes as a plain integer.
select count(*)::int as owners
from memberships m
join roles r on r.id = m.role_id
where m.organization_id = $1
  and r.is_owner = true;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Remove a user from an organization.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_membership(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Remove a user from an organization.
delete from memberships
where organization_id = $1
  and user_id = $2;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Delete a role. Its permissions cascade; a role still assigned to a member is
/// blocked by the membership foreign key.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_role(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Delete a role. Its permissions cascade; a role still assigned to a member is
-- blocked by the membership foreign key.
delete from roles
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Clear a role's permissions (before re-inserting the new set on save).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_role_permissions(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Clear a role's permissions (before re-inserting the new set on save).
delete from role_permissions
where role_id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Revoke a session (logout). Idempotent.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_session_by_token_hash(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Revoke a session (logout). Idempotent.
delete from sessions
where token_hash = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_booking_by_id` query
/// defined in `./src/db/sql/find_booking_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindBookingByIdRow {
  FindBookingByIdRow(
    id: String,
    organization_id: String,
    guest_id: Option(String),
    status: String,
  )
}

/// Find a single booking by id.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_booking_by_id(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(FindBookingByIdRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use guest_id <- decode.field(2, decode.optional(decode.string))
    use status <- decode.field(3, decode.string)
    decode.success(FindBookingByIdRow(id:, organization_id:, guest_id:, status:))
  }

  "-- Find a single booking by id.
select id, organization_id, guest_id, status
from bookings
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_credential_by_user` query
/// defined in `./src/db/sql/find_credential_by_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindCredentialByUserRow {
  FindCredentialByUserRow(password_hash: String)
}

/// The stored password hash for a user.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_credential_by_user(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(FindCredentialByUserRow), sql.SqlError),
) {
  let decoder = {
    use password_hash <- decode.field(0, decode.string)
    decode.success(FindCredentialByUserRow(password_hash:))
  }

  "-- The stored password hash for a user.
select password_hash
from user_credentials
where user_id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_free_unit_in_room_type` query
/// defined in `./src/db/sql/find_free_unit_in_room_type.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindFreeUnitInRoomTypeRow {
  FindFreeUnitInRoomTypeRow(id: String)
}

/// A bookable leaf child of the room-type with no overlapping pin over the
/// period — a free physical bed to assign at check-in.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_free_unit_in_room_type(
  db: sql.Connection,
  arg_1: String,
  arg_2: Date,
  arg_3: Date,
) -> promise.Promise(
  Result(sql.Returned(FindFreeUnitInRoomTypeRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    decode.success(FindFreeUnitInRoomTypeRow(id:))
  }

  "-- A bookable leaf child of the room-type with no overlapping pin over the
-- period — a free physical bed to assign at check-in.
select leaf.id
from spaces leaf
where leaf.parent_id = $1 and leaf.is_grouping = false and leaf.bookable = true
  and not exists (
    select 1 from booking_demand d
    where d.is_pin and d.space_id = leaf.id
      and d.period && daterange($2, $3, '[)')
  )
order by leaf.created_at asc
limit 1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(date_to_string(arg_2)))
  |> sql.parameter(sql.text(date_to_string(arg_3)))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_guest_by_id` query
/// defined in `./src/db/sql/find_guest_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindGuestByIdRow {
  FindGuestByIdRow(
    id: String,
    organization_id: String,
    user_id: Option(String),
    name: String,
    email: String,
  )
}

/// Find a single guest by id.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_guest_by_id(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(FindGuestByIdRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use user_id <- decode.field(2, decode.optional(decode.string))
    use name <- decode.field(3, decode.string)
    use email <- decode.field(4, decode.string)
    decode.success(FindGuestByIdRow(
      id:,
      organization_id:,
      user_id:,
      name:,
      email:,
    ))
  }

  "-- Find a single guest by id.
select id, organization_id, user_id, name, email
from guests
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_membership` query
/// defined in `./src/db/sql/find_membership.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindMembershipRow {
  FindMembershipRow(
    id: String,
    organization_id: String,
    user_id: String,
    role_id: String,
  )
}

/// A user's membership in an organization.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_membership(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(FindMembershipRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use user_id <- decode.field(2, decode.string)
    use role_id <- decode.field(3, decode.string)
    decode.success(FindMembershipRow(id:, organization_id:, user_id:, role_id:))
  }

  "-- A user's membership in an organization.
select id, organization_id, user_id, role_id
from memberships
where organization_id = $1
  and user_id = $2;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_organization_by_id` query
/// defined in `./src/db/sql/find_organization_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindOrganizationByIdRow {
  FindOrganizationByIdRow(id: String, slug: String, name: String)
}

/// Find a single organization by id.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_organization_by_id(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(FindOrganizationByIdRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(FindOrganizationByIdRow(id:, slug:, name:))
  }

  "-- Find a single organization by id.
select id, slug, name
from organizations
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_organization_by_slug` query
/// defined in `./src/db/sql/find_organization_by_slug.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindOrganizationBySlugRow {
  FindOrganizationBySlugRow(id: String, slug: String, name: String)
}

/// Find a single organization by its slug.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_organization_by_slug(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(FindOrganizationBySlugRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(FindOrganizationBySlugRow(id:, slug:, name:))
  }

  "-- Find a single organization by its slug.
select id, slug, name
from organizations
where slug = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_role_by_id` query
/// defined in `./src/db/sql/find_role_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindRoleByIdRow {
  FindRoleByIdRow(
    id: String,
    organization_id: String,
    name: String,
    is_owner: Bool,
  )
}

/// A single role row (permissions fetched separately).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_role_by_id(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(FindRoleByIdRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use is_owner <- decode.field(3, decode.bool)
    decode.success(FindRoleByIdRow(id:, organization_id:, name:, is_owner:))
  }

  "-- A single role row (permissions fetched separately).
select id, organization_id, name, is_owner
from roles
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_session_user_by_token_hash` query
/// defined in `./src/db/sql/find_session_user_by_token_hash.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindSessionUserByTokenHashRow {
  FindSessionUserByTokenHashRow(user_id: String)
}

/// The user behind a session token hash, only while the session is unexpired.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_session_user_by_token_hash(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(FindSessionUserByTokenHashRow), sql.SqlError),
) {
  let decoder = {
    use user_id <- decode.field(0, decode.string)
    decode.success(FindSessionUserByTokenHashRow(user_id:))
  }

  "-- The user behind a session token hash, only while the session is unexpired.
select user_id
from sessions
where token_hash = $1
  and expires_at > now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_space_by_id` query
/// defined in `./src/db/sql/find_space_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindSpaceByIdRow {
  FindSpaceByIdRow(
    id: String,
    organization_id: String,
    parent_id: Option(String),
    is_grouping: Bool,
    label: String,
    name: String,
    bookable: Bool,
  )
}

/// Find a single space by id.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_space_by_id(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(FindSpaceByIdRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use parent_id <- decode.field(2, decode.optional(decode.string))
    use is_grouping <- decode.field(3, decode.bool)
    use label <- decode.field(4, decode.string)
    use name <- decode.field(5, decode.string)
    use bookable <- decode.field(6, decode.bool)
    decode.success(FindSpaceByIdRow(
      id:,
      organization_id:,
      parent_id:,
      is_grouping:,
      label:,
      name:,
      bookable:,
    ))
  }

  "-- Find a single space by id.
select id, organization_id, parent_id, is_grouping, label, name, bookable
from spaces
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_user_by_email` query
/// defined in `./src/db/sql/find_user_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByEmailRow {
  FindUserByEmailRow(id: String, email: String, name: String)
}

/// Find a single user by email.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_email(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(FindUserByEmailRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use email <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(FindUserByEmailRow(id:, email:, name:))
  }

  "-- Find a single user by email.
select id, email, name
from users
where email = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `find_user_by_id` query
/// defined in `./src/db/sql/find_user_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindUserByIdRow {
  FindUserByIdRow(id: String, email: String, name: String)
}

/// Find a single user by id.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_user_by_id(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(FindUserByIdRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use email <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(FindUserByIdRow(id:, email:, name:))
  }

  "-- Find a single user by id.
select id, email, name
from users
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Insert a booking with no guest (a maintenance/blocking hold).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_booking(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Insert a booking with no guest (a maintenance/blocking hold).
insert into bookings (id, organization_id, status, updated_at)
values ($1, $2, $3, now());
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Insert a booking item pinned to a specific space (a bed, or a whole grouping).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_booking_item_assigned(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Date,
  arg_4: Date,
  arg_5: String,
  arg_6: String,
  arg_7: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Insert a booking item pinned to a specific space (a bed, or a whole grouping).
insert into booking_items
  (id, booking_id, period, kind, target_space_id, assigned_space_id, updated_at)
values ($1, $2, daterange($3, $4, '[)'), $5, $6, $7, now());
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(date_to_string(arg_3)))
  |> sql.parameter(sql.text(date_to_string(arg_4)))
  |> sql.parameter(sql.text(arg_5))
  |> sql.parameter(sql.text(arg_6))
  |> sql.parameter(sql.text(arg_7))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Insert an unassigned booking item (a hold against a one-level room-type).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_booking_item_unassigned(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Date,
  arg_4: Date,
  arg_5: String,
  arg_6: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Insert an unassigned booking item (a hold against a one-level room-type).
insert into booking_items
  (id, booking_id, period, kind, target_space_id, updated_at)
values ($1, $2, daterange($3, $4, '[)'), $5, $6, now());
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(date_to_string(arg_3)))
  |> sql.parameter(sql.text(date_to_string(arg_4)))
  |> sql.parameter(sql.text(arg_5))
  |> sql.parameter(sql.text(arg_6))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Insert a booking for a guest.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_booking_with_guest(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Insert a booking for a guest.
insert into bookings (id, organization_id, guest_id, status, updated_at)
values ($1, $2, $3, $4, now());
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.parameter(sql.text(arg_4))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a user's password hash.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_credential(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a user's password hash.
insert into user_credentials (user_id, password_hash, updated_at)
values ($1, $2, now())
on conflict (user_id) do update
set password_hash = excluded.password_hash,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a walk-in guest (no linked user account): insert it, or update its
/// fields if the id already exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_guest(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a walk-in guest (no linked user account): insert it, or update its
-- fields if the id already exists.
insert into guests (id, organization_id, name, email, updated_at)
values ($1, $2, $3, $4, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    user_id = null,
    name = excluded.name,
    email = excluded.email,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.parameter(sql.text(arg_4))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a guest linked to a user account: insert it, or update its fields if
/// the id already exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_guest_with_user(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a guest linked to a user account: insert it, or update its fields if
-- the id already exists.
insert into guests (id, organization_id, user_id, name, email, updated_at)
values ($1, $2, $3, $4, $5, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    user_id = excluded.user_id,
    name = excluded.name,
    email = excluded.email,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.parameter(sql.text(arg_4))
  |> sql.parameter(sql.text(arg_5))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Materialize an unassigned hold: a single demand row on the room-type.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_hold_demand(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Date,
  arg_4: Date,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Materialize an unassigned hold: a single demand row on the room-type.
insert into booking_demand (booking_item_id, space_id, period, is_pin)
values ($1, $2, daterange($3, $4, '[)'), false);
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(date_to_string(arg_3)))
  |> sql.parameter(sql.text(date_to_string(arg_4)))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a membership: add the user to the org, or change their role.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_membership(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a membership: add the user to the org, or change their role.
insert into memberships (id, organization_id, user_id, role_id, updated_at)
values ($1, $2, $3, $4, now())
on conflict (organization_id, user_id) do update
set role_id = excluded.role_id,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.parameter(sql.text(arg_4))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert an organization: insert it, or update slug/name if the id exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_organization(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert an organization: insert it, or update slug/name if the id exists.
insert into organizations (id, slug, name, updated_at)
values ($1, $2, $3, now())
on conflict (id) do update
set slug = excluded.slug,
    name = excluded.name,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Materialize an assigned item's demand: the booked node plus all its
/// descendants, as pinned rows. The partial EXCLUDE rejects any overlapping pin
/// on the same node.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_pin_demand(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Date,
  arg_4: Date,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Materialize an assigned item's demand: the booked node plus all its
-- descendants, as pinned rows. The partial EXCLUDE rejects any overlapping pin
-- on the same node.
with recursive subtree (id) as (
  select id from spaces where id = $2
  union all
  select s.id from spaces s join subtree t on s.parent_id = t.id
)
insert into booking_demand (booking_item_id, space_id, period, is_pin)
select $1, subtree.id, daterange($3, $4, '[)'), true
from subtree;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(date_to_string(arg_3)))
  |> sql.parameter(sql.text(date_to_string(arg_4)))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a role row (its permissions are written separately).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_role(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: Bool,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a role row (its permissions are written separately).
insert into roles (id, organization_id, name, is_owner, updated_at)
values ($1, $2, $3, $4, now())
on conflict (id) do update
set name = excluded.name,
    is_owner = excluded.is_owner,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.parameter(sql.bool(arg_4))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Grant a permission to a role.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_role_permission(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Grant a permission to a role.
insert into role_permissions (role_id, permission)
values ($1, $2)
on conflict do nothing;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Create a session. The token is stored only as its hash; the row expires in
/// 30 days (TTL handled here so no timestamp parameter is needed).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_session(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Create a session. The token is stored only as its hash; the row expires in
-- 30 days (TTL handled here so no timestamp parameter is needed).
insert into sessions (token_hash, user_id, expires_at)
values ($1, $2, now() + interval '30 days');
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a root space (no parent): insert it, or update its fields if the id
/// already exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_space(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Bool,
  arg_4: String,
  arg_5: String,
  arg_6: Bool,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a root space (no parent): insert it, or update its fields if the id
-- already exists.
insert into spaces (id, organization_id, is_grouping, label, name, bookable, updated_at)
values ($1, $2, $3, $4, $5, $6, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    parent_id = null,
    is_grouping = excluded.is_grouping,
    label = excluded.label,
    name = excluded.name,
    bookable = excluded.bookable,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.bool(arg_3))
  |> sql.parameter(sql.text(arg_4))
  |> sql.parameter(sql.text(arg_5))
  |> sql.parameter(sql.bool(arg_6))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a nested space (with a parent): insert it, or update its fields if the
/// id already exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_space_with_parent(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
  arg_4: Bool,
  arg_5: String,
  arg_6: String,
  arg_7: Bool,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a nested space (with a parent): insert it, or update its fields if the
-- id already exists.
insert into spaces (id, organization_id, parent_id, is_grouping, label, name, bookable, updated_at)
values ($1, $2, $3, $4, $5, $6, $7, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    parent_id = excluded.parent_id,
    is_grouping = excluded.is_grouping,
    label = excluded.label,
    name = excluded.name,
    bookable = excluded.bookable,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.parameter(sql.bool(arg_4))
  |> sql.parameter(sql.text(arg_5))
  |> sql.parameter(sql.text(arg_6))
  |> sql.parameter(sql.bool(arg_7))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a user: insert it, or update email/name if the id already exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_user(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a user: insert it, or update email/name if the id already exists.
insert into users (id, email, name, updated_at)
values ($1, $2, $3, now())
on conflict (id) do update
set email = excluded.email,
    name = excluded.name,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.text(arg_3))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `item_room_types` query
/// defined in `./src/db/sql/item_room_types.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ItemRoomTypesRow {
  ItemRoomTypesRow(room_type: String)
}

/// The room-types whose capacity an item consumes: the parents of the bookable
/// leaf nodes it pins, plus the room-type a hold targets.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn item_room_types(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(ItemRoomTypesRow), sql.SqlError)) {
  let decoder = {
    use room_type <- decode.field(0, decode.string)
    decode.success(ItemRoomTypesRow(room_type:))
  }

  "-- The room-types whose capacity an item consumes: the parents of the bookable
-- leaf nodes it pins, plus the room-type a hold targets.
select room_type
from (
  select distinct s.parent_id as room_type
  from booking_demand d
  join spaces s on s.id = d.space_id
  where d.booking_item_id = $1 and d.is_pin = true and s.is_grouping = false
  union
  select d.space_id as room_type
  from booking_demand d
  where d.booking_item_id = $1 and d.is_pin = false
) t
where room_type is not null;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_booking_items` query
/// defined in `./src/db/sql/list_booking_items.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListBookingItemsRow {
  ListBookingItemsRow(
    id: String,
    booking_id: String,
    check_in: String,
    check_out: String,
    kind: String,
    target_space_id: String,
    assigned_space_id: Option(String),
  )
}

/// List a booking's items, period rendered as ISO date text.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_booking_items(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(ListBookingItemsRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use booking_id <- decode.field(1, decode.string)
    use check_in <- decode.field(2, decode.string)
    use check_out <- decode.field(3, decode.string)
    use kind <- decode.field(4, decode.string)
    use target_space_id <- decode.field(5, decode.string)
    use assigned_space_id <- decode.field(6, decode.optional(decode.string))
    decode.success(ListBookingItemsRow(
      id:,
      booking_id:,
      check_in:,
      check_out:,
      kind:,
      target_space_id:,
      assigned_space_id:,
    ))
  }

  "-- List a booking's items, period rendered as ISO date text.
select id, booking_id,
  to_char(lower(period), 'YYYY-MM-DD') as check_in,
  to_char(upper(period), 'YYYY-MM-DD') as check_out,
  kind, target_space_id, assigned_space_id
from booking_items
where booking_id = $1
order by created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_bookings_by_organization` query
/// defined in `./src/db/sql/list_bookings_by_organization.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListBookingsByOrganizationRow {
  ListBookingsByOrganizationRow(
    id: String,
    organization_id: String,
    guest_id: Option(String),
    status: String,
  )
}

/// List an organization's bookings, newest first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_bookings_by_organization(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListBookingsByOrganizationRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use guest_id <- decode.field(2, decode.optional(decode.string))
    use status <- decode.field(3, decode.string)
    decode.success(ListBookingsByOrganizationRow(
      id:,
      organization_id:,
      guest_id:,
      status:,
    ))
  }

  "-- List an organization's bookings, newest first.
select id, organization_id, guest_id, status
from bookings
where organization_id = $1
order by created_at desc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_guests_by_organization` query
/// defined in `./src/db/sql/list_guests_by_organization.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListGuestsByOrganizationRow {
  ListGuestsByOrganizationRow(
    id: String,
    organization_id: String,
    user_id: Option(String),
    name: String,
    email: String,
  )
}

/// List one organization's guests, most recently created first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_guests_by_organization(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListGuestsByOrganizationRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use user_id <- decode.field(2, decode.optional(decode.string))
    use name <- decode.field(3, decode.string)
    use email <- decode.field(4, decode.string)
    decode.success(ListGuestsByOrganizationRow(
      id:,
      organization_id:,
      user_id:,
      name:,
      email:,
    ))
  }

  "-- List one organization's guests, most recently created first.
select id, organization_id, user_id, name, email
from guests
where organization_id = $1
order by created_at desc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_memberships_by_organization` query
/// defined in `./src/db/sql/list_memberships_by_organization.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListMembershipsByOrganizationRow {
  ListMembershipsByOrganizationRow(
    id: String,
    organization_id: String,
    user_id: String,
    role_id: String,
  )
}

/// An organization's memberships, oldest first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_memberships_by_organization(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListMembershipsByOrganizationRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use user_id <- decode.field(2, decode.string)
    use role_id <- decode.field(3, decode.string)
    decode.success(ListMembershipsByOrganizationRow(
      id:,
      organization_id:,
      user_id:,
      role_id:,
    ))
  }

  "-- An organization's memberships, oldest first.
select id, organization_id, user_id, role_id
from memberships
where organization_id = $1
order by created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_organizations` query
/// defined in `./src/db/sql/list_organizations.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListOrganizationsRow {
  ListOrganizationsRow(id: String, slug: String, name: String)
}

/// List all organizations, most recently created first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_organizations(
  db: sql.Connection,
) -> promise.Promise(Result(sql.Returned(ListOrganizationsRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(ListOrganizationsRow(id:, slug:, name:))
  }

  "-- List all organizations, most recently created first.
select id, slug, name
from organizations
order by created_at desc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_role_permissions` query
/// defined in `./src/db/sql/list_role_permissions.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListRolePermissionsRow {
  ListRolePermissionsRow(permission: String)
}

/// A role's permissions.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_role_permissions(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(ListRolePermissionsRow), sql.SqlError)) {
  let decoder = {
    use permission <- decode.field(0, decode.string)
    decode.success(ListRolePermissionsRow(permission:))
  }

  "-- A role's permissions.
select permission
from role_permissions
where role_id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_roles_by_organization` query
/// defined in `./src/db/sql/list_roles_by_organization.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListRolesByOrganizationRow {
  ListRolesByOrganizationRow(
    id: String,
    organization_id: String,
    name: String,
    is_owner: Bool,
  )
}

/// An organization's role rows, oldest first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_roles_by_organization(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListRolesByOrganizationRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    use is_owner <- decode.field(3, decode.bool)
    decode.success(ListRolesByOrganizationRow(
      id:,
      organization_id:,
      name:,
      is_owner:,
    ))
  }

  "-- An organization's role rows, oldest first.
select id, organization_id, name, is_owner
from roles
where organization_id = $1
order by created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_room_types_by_organization` query
/// defined in `./src/db/sql/list_room_types_by_organization.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListRoomTypesByOrganizationRow {
  ListRoomTypesByOrganizationRow(
    id: String,
    name: String,
    label: String,
    capacity: Int,
  )
}

/// One-level room-types in an organization: groupings with no grouping children
/// and at least one bookable leaf child, with their bookable capacity.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_room_types_by_organization(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListRoomTypesByOrganizationRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use label <- decode.field(2, decode.string)
    use capacity <- decode.field(3, int_decoder())
    decode.success(ListRoomTypesByOrganizationRow(id:, name:, label:, capacity:))
  }

  "-- One-level room-types in an organization: groupings with no grouping children
-- and at least one bookable leaf child, with their bookable capacity.
select g.id, g.name, g.label,
  (
    select count(*) from spaces leaf
    where leaf.parent_id = g.id and leaf.is_grouping = false and leaf.bookable = true
  )::int as capacity
from spaces g
where g.organization_id = $1 and g.is_grouping = true
  and not exists (
    select 1 from spaces c where c.parent_id = g.id and c.is_grouping = true
  )
  and exists (
    select 1 from spaces c
    where c.parent_id = g.id and c.is_grouping = false and c.bookable = true
  )
order by g.created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_spaces_by_organization` query
/// defined in `./src/db/sql/list_spaces_by_organization.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListSpacesByOrganizationRow {
  ListSpacesByOrganizationRow(
    id: String,
    organization_id: String,
    parent_id: Option(String),
    is_grouping: Bool,
    label: String,
    name: String,
    bookable: Bool,
  )
}

/// List one organization's spaces, oldest first (so parents tend to precede
/// their children when assembling the tree).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_spaces_by_organization(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListSpacesByOrganizationRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use parent_id <- decode.field(2, decode.optional(decode.string))
    use is_grouping <- decode.field(3, decode.bool)
    use label <- decode.field(4, decode.string)
    use name <- decode.field(5, decode.string)
    use bookable <- decode.field(6, decode.bool)
    decode.success(ListSpacesByOrganizationRow(
      id:,
      organization_id:,
      parent_id:,
      is_grouping:,
      label:,
      name:,
      bookable:,
    ))
  }

  "-- List one organization's spaces, oldest first (so parents tend to precede
-- their children when assembling the tree).
select id, organization_id, parent_id, is_grouping, label, name, bookable
from spaces
where organization_id = $1
order by created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_spaces_by_parent` query
/// defined in `./src/db/sql/list_spaces_by_parent.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListSpacesByParentRow {
  ListSpacesByParentRow(
    id: String,
    organization_id: String,
    parent_id: Option(String),
    is_grouping: Bool,
    label: String,
    name: String,
    bookable: Bool,
  )
}

/// List the direct children of a space, oldest first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_spaces_by_parent(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(ListSpacesByParentRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use organization_id <- decode.field(1, decode.string)
    use parent_id <- decode.field(2, decode.optional(decode.string))
    use is_grouping <- decode.field(3, decode.bool)
    use label <- decode.field(4, decode.string)
    use name <- decode.field(5, decode.string)
    use bookable <- decode.field(6, decode.bool)
    decode.success(ListSpacesByParentRow(
      id:,
      organization_id:,
      parent_id:,
      is_grouping:,
      label:,
      name:,
      bookable:,
    ))
  }

  "-- List the direct children of a space, oldest first.
select id, organization_id, parent_id, is_grouping, label, name, bookable
from spaces
where parent_id = $1
order by created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_user_organizations` query
/// defined in `./src/db/sql/list_user_organizations.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListUserOrganizationsRow {
  ListUserOrganizationsRow(id: String, slug: String, name: String)
}

/// The organizations a user belongs to, oldest first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_user_organizations(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(ListUserOrganizationsRow), sql.SqlError),
) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use slug <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(ListUserOrganizationsRow(id:, slug:, name:))
  }

  "-- The organizations a user belongs to, oldest first.
select o.id, o.slug, o.name
from organizations o
join memberships m on m.organization_id = o.id
where m.user_id = $1
order by o.created_at asc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `list_users` query
/// defined in `./src/db/sql/list_users.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListUsersRow {
  ListUsersRow(id: String, email: String, name: String)
}

/// List all users, most recently created first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_users(
  db: sql.Connection,
) -> promise.Promise(Result(sql.Returned(ListUsersRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use email <- decode.field(1, decode.string)
    use name <- decode.field(2, decode.string)
    decode.success(ListUsersRow(id:, email:, name:))
  }

  "-- List all users, most recently created first.
select id, email, name
from users
order by created_at desc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Free a booking's held space when it leaves a blocking status: delete all its
/// demand rows. The booking and its items remain, for history.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn release_booking_demand(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Free a booking's held space when it leaves a blocking status: delete all its
-- demand rows. The booking and its items remain, for history.
delete from booking_demand
where booking_item_id in (
  select id from booking_items where booking_id = $1
);
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `room_type_capacity` query
/// defined in `./src/db/sql/room_type_capacity.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RoomTypeCapacityRow {
  RoomTypeCapacityRow(capacity: Int)
}

/// Bookable capacity of a one-level room-type: its bookable leaf children.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn room_type_capacity(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(RoomTypeCapacityRow), sql.SqlError)) {
  let decoder = {
    use capacity <- decode.field(0, int_decoder())
    decode.success(RoomTypeCapacityRow(capacity:))
  }

  "-- Bookable capacity of a one-level room-type: its bookable leaf children.
select count(*)::int as capacity
from spaces
where parent_id = $1 and is_grouping = false and bookable = true;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `room_type_peak_demand` query
/// defined in `./src/db/sql/room_type_peak_demand.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type RoomTypePeakDemandRow {
  RoomTypePeakDemandRow(peak: Int)
}

/// Peak concurrent demand on a room-type over [check_in, check_out): the max,
/// across the period's candidate dates, of pinned bookable leaf children plus
/// unassigned holds on the room-type that cover that date.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn room_type_peak_demand(
  db: sql.Connection,
  arg_1: String,
  arg_2: Date,
  arg_3: Date,
) -> promise.Promise(Result(sql.Returned(RoomTypePeakDemandRow), sql.SqlError)) {
  let decoder = {
    use peak <- decode.field(0, int_decoder())
    decode.success(RoomTypePeakDemandRow(peak:))
  }

  "-- Peak concurrent demand on a room-type over [check_in, check_out): the max,
-- across the period's candidate dates, of pinned bookable leaf children plus
-- unassigned holds on the room-type that cover that date.
with demand as (
  select dd.period
  from spaces leaf
  join booking_demand dd on dd.is_pin and dd.space_id = leaf.id
  where leaf.parent_id = $1 and leaf.is_grouping = false and leaf.bookable = true
  union all
  select period
  from booking_demand
  where is_pin = false and space_id = $1
),
candidates as (
  select lower(period) as d from demand
  where lower(period) >= $2 and lower(period) < $3
  union
  select $2
)
select coalesce(
  max((select count(*) from demand x where x.period @> c.d)),
  0
)::int as peak
from candidates c;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(date_to_string(arg_2)))
  |> sql.parameter(sql.text(date_to_string(arg_3)))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `space_has_active_demand` query
/// defined in `./src/db/sql/space_has_active_demand.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SpaceHasActiveDemandRow {
  SpaceHasActiveDemandRow(active: Int)
}

/// Whether any active booking demand falls within a space's subtree (used to
/// block reparenting a space that has live bookings).
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn space_has_active_demand(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(
  Result(sql.Returned(SpaceHasActiveDemandRow), sql.SqlError),
) {
  let decoder = {
    use active <- decode.field(0, int_decoder())
    decode.success(SpaceHasActiveDemandRow(active:))
  }

  "-- Whether any active booking demand falls within a space's subtree (used to
-- block reparenting a space that has live bookings).
with recursive subtree (id) as (
  select id from spaces where id = $1
  union all
  select s.id from spaces s join subtree t on s.parent_id = t.id
)
select (exists (
  select 1 from booking_demand d
  join subtree t on t.id = d.space_id
))::int as active;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Update a booking's status.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_booking_status(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Update a booking's status.
update bookings set status = $2, updated_at = now() where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// A row you get from running the `validate_room_type` query
/// defined in `./src/db/sql/validate_room_type.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ValidateRoomTypeRow {
  ValidateRoomTypeRow(valid: Int)
}

/// Whether a space is a one-level room-type: a grouping with no grouping children
/// and at least one bookable leaf child.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn validate_room_type(
  db: sql.Connection,
  arg_1: String,
) -> promise.Promise(Result(sql.Returned(ValidateRoomTypeRow), sql.SqlError)) {
  let decoder = {
    use valid <- decode.field(0, int_decoder())
    decode.success(ValidateRoomTypeRow(valid:))
  }

  "-- Whether a space is a one-level room-type: a grouping with no grouping children
-- and at least one bookable leaf child.
select (
  exists (select 1 from spaces where id = $1 and is_grouping = true)
  and not exists (
    select 1 from spaces c where c.parent_id = $1 and c.is_grouping = true
  )
  and exists (
    select 1 from spaces c
    where c.parent_id = $1 and c.is_grouping = false and c.bookable = true
  )
)::int as valid;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

// --- Encoding/decoding utils -------------------------------------------------

fn pad_int(value: Int, length: Int) -> String {
  string.pad_start(int.to_string(value), to: length, with: "0")
}

/// A decoder for `Int`s coming from a Postgres query. Bun returns 64 bit
/// integers (`bigint`/`int8`) as strings to avoid losing precision, so we
/// accept both a number and a string.
///
fn int_decoder() {
  decode.one_of(decode.int, or: [
    {
      use string <- decode.then(decode.string)
      case int.parse(string) {
        Ok(int) -> decode.success(int)
        Error(_) -> decode.failure(0, "Int")
      }
    },
  ])
}

/// Encodes a `Date` as the `YYYY-MM-DD` string Postgres expects.
///
fn date_to_string(date: calendar.Date) -> String {
  let calendar.Date(year, month, day) = date
  pad_int(year, 4)
  <> "-"
  <> pad_int(calendar.month_to_int(month), 2)
  <> "-"
  <> pad_int(day, 2)
}
