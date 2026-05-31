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
    decode.success(FindSpaceByIdRow(
      id:,
      organization_id:,
      parent_id:,
      is_grouping:,
      label:,
      name:,
    ))
  }

  "-- Find a single space by id.
select id, organization_id, parent_id, is_grouping, label, name
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
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a root space (no parent): insert it, or update its fields if the id
-- already exists.
insert into spaces (id, organization_id, is_grouping, label, name, updated_at)
values ($1, $2, $3, $4, $5, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    parent_id = null,
    is_grouping = excluded.is_grouping,
    label = excluded.label,
    name = excluded.name,
    updated_at = now();
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.parameter(sql.text(arg_2))
  |> sql.parameter(sql.bool(arg_3))
  |> sql.parameter(sql.text(arg_4))
  |> sql.parameter(sql.text(arg_5))
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
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a nested space (with a parent): insert it, or update its fields if the
-- id already exists.
insert into spaces (id, organization_id, parent_id, is_grouping, label, name, updated_at)
values ($1, $2, $3, $4, $5, $6, now())
on conflict (id) do update
set organization_id = excluded.organization_id,
    parent_id = excluded.parent_id,
    is_grouping = excluded.is_grouping,
    label = excluded.label,
    name = excluded.name,
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
    decode.success(ListSpacesByOrganizationRow(
      id:,
      organization_id:,
      parent_id:,
      is_grouping:,
      label:,
      name:,
    ))
  }

  "-- List one organization's spaces, oldest first (so parents tend to precede
-- their children when assembling the tree).
select id, organization_id, parent_id, is_grouping, label, name
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
    decode.success(ListSpacesByParentRow(
      id:,
      organization_id:,
      parent_id:,
      is_grouping:,
      label:,
      name:,
    ))
  }

  "-- List the direct children of a space, oldest first.
select id, organization_id, parent_id, is_grouping, label, name
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

// --- Encoding/decoding utils -------------------------------------------------

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
