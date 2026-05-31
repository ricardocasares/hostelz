//// Postgres-backed adapter for the guest persistence port. Builds a
//// `guest_repo.GuestRepo` whose closures run the generated squirrel queries
//// (`db/sql`) against a brioche connection. Stored rows are turned back into
//// domain `Guest` values through the smart constructors, so a row that no
//// longer satisfies the domain rules surfaces as `Corrupt` rather than a
//// silently-invalid `Guest`.

import brioche/sql as db
import db/sql as queries
import domain/email
import domain/guest.{type Guest, type GuestId}
import domain/guest_repo.{
  type GuestRepo, type RepoError, Corrupt, GuestRepo, NotFound, StorageError,
}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string

/// Build a Postgres-backed `GuestRepo` over an existing connection. The
/// connection is captured by the returned closures — no global mutable state.
pub fn new(conn: db.Connection) -> GuestRepo {
  GuestRepo(
    save: fn(g) { save(conn, g) },
    find: fn(id) { find(conn, id) },
    list_all: fn() { list_all(conn) },
  )
}

fn save(conn: db.Connection, g: Guest) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.insert_guest(
    conn,
    guest.guest_id(guest.id(g)),
    guest.name(g),
    email.to_string(guest.email(g)),
  ))
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn find(conn: db.Connection, id: GuestId) -> Promise(Result(Guest, RepoError)) {
  use res <- promise.map(queries.find_guest_by_id(conn, guest.guest_id(id)))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(row.id, row.name, row.email)
  }
}

fn list_all(conn: db.Connection) -> Promise(Result(List(Guest), RepoError)) {
  use res <- promise.map(queries.list_guests(conn))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) { reconstruct(row.id, row.name, row.email) })
  }
}

/// Rebuild a `Guest` from stored column values, re-running the domain smart
/// constructors. Exposed so the reconstruction — the one piece of adapter logic
/// with real branching — can be unit-tested without a database.
pub fn reconstruct(
  id: String,
  name: String,
  mail: String,
) -> Result(Guest, RepoError) {
  use gid <- result.try(guest.new_id(id) |> result.map_error(corrupt))
  use address <- result.try(email.new(mail) |> result.map_error(corrupt))
  guest.new(gid, name, address) |> result.map_error(corrupt)
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
