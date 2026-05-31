//// This module contains the code to run the sql queries defined in
//// `./src/db/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import brioche/sql
import gleam/dynamic/decode
import gleam/javascript/promise

/// A row you get from running the `find_guest_by_id` query
/// defined in `./src/db/sql/find_guest_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindGuestByIdRow {
  FindGuestByIdRow(id: String, name: String, email: String)
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
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    decode.success(FindGuestByIdRow(id:, name:, email:))
  }

  "-- Find a single guest by id.
select id, name, email
from guests
where id = $1;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.parameter(sql.text(arg_1))
  |> sql.returning(decoder)
  |> sql.execute(db)
}

/// Upsert a guest: insert it, or update name/email if the id already exists.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_guest(
  db: sql.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: String,
) -> promise.Promise(Result(sql.Returned(Nil), sql.SqlError)) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Upsert a guest: insert it, or update name/email if the id already exists.
insert into guests (id, name, email, updated_at)
values ($1, $2, $3, now())
on conflict (id) do update
set name = excluded.name,
    email = excluded.email,
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

/// A row you get from running the `list_guests` query
/// defined in `./src/db/sql/list_guests.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListGuestsRow {
  ListGuestsRow(id: String, name: String, email: String)
}

/// List all guests, most recently created first.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_guests(
  db: sql.Connection,
) -> promise.Promise(Result(sql.Returned(ListGuestsRow), sql.SqlError)) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    decode.success(ListGuestsRow(id:, name:, email:))
  }

  "-- List all guests, most recently created first.
select id, name, email
from guests
order by created_at desc;
"
  |> sql.query
  |> sql.format(sql.Tuple)
  |> sql.returning(decoder)
  |> sql.execute(db)
}
