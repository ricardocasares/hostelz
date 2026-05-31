//// This module contains the code to run the sql queries defined in
//// `./src/db/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import brioche/sql
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option.{type Option}

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
