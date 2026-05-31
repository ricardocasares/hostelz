//// Postgres-backed adapter for the guest persistence port. Builds a
//// `guest_repo.GuestRepo` whose closures run the generated squirrel queries
//// (`db/sql`) against a brioche connection. A guest belongs to an organization
//// and may be linked to a user account: a walk-in (`None`) is written with the
//// `insert_guest` upsert (user_id left NULL), a registered guest with
//// `insert_guest_with_user`. Stored rows are turned back into domain `Guest`
//// values through the smart constructors, so a row that no longer satisfies the
//// domain rules surfaces as `Corrupt`.

import brioche/sql as db
import db/sql as queries
import domain/email
import domain/guest.{type Guest, type GuestId}
import domain/guest_repo.{type GuestRepo, GuestRepo}
import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError, Corrupt, NotFound, StorageError}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Build a Postgres-backed `GuestRepo` over an existing connection. The
/// connection is captured by the returned closures — no global mutable state.
pub fn new(conn: db.Connection) -> GuestRepo {
  GuestRepo(
    save: fn(g) { save(conn, g) },
    find: fn(id) { find(conn, id) },
    list_by_organization: fn(org_id) { list_by_organization(conn, org_id) },
  )
}

fn save(conn: db.Connection, g: Guest) -> Promise(Result(Nil, RepoError)) {
  let id = guest.guest_id(guest.id(g))
  let org = organization.organization_id(guest.organization_id(g))
  let name = guest.name(g)
  let mail = email.to_string(guest.email(g))
  let saved = case guest.user_id(g) {
    Some(uid) ->
      queries.insert_guest_with_user(
        conn,
        id,
        org,
        user.user_id(uid),
        name,
        mail,
      )
    None -> queries.insert_guest(conn, id, org, name, mail)
  }
  use res <- promise.map(saved)
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
      reconstruct(row.id, row.organization_id, row.user_id, row.name, row.email)
  }
}

fn list_by_organization(
  conn: db.Connection,
  org_id: OrganizationId,
) -> Promise(Result(List(Guest), RepoError)) {
  use res <- promise.map(queries.list_guests_by_organization(
    conn,
    organization.organization_id(org_id),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) {
        reconstruct(
          row.id,
          row.organization_id,
          row.user_id,
          row.name,
          row.email,
        )
      })
  }
}

/// Rebuild a `Guest` from stored column values, re-running the domain smart
/// constructors. The `user_id` column is nullable — `None` is a walk-in.
/// Exposed so the reconstruction can be unit-tested without a database.
pub fn reconstruct(
  id: String,
  organization_id: String,
  user_id: Option(String),
  name: String,
  mail: String,
) -> Result(Guest, RepoError) {
  use gid <- result.try(guest.new_id(id) |> result.map_error(corrupt))
  use org_id <- result.try(
    organization.new_id(organization_id) |> result.map_error(corrupt),
  )
  use uid <- result.try(reconstruct_user_id(user_id))
  use address <- result.try(email.new(mail) |> result.map_error(corrupt))
  guest.new(gid, org_id, uid, name, address) |> result.map_error(corrupt)
}

fn reconstruct_user_id(
  user_id: Option(String),
) -> Result(Option(UserId), RepoError) {
  case user_id {
    None -> Ok(None)
    Some(raw) ->
      user.new_id(raw) |> result.map(Some) |> result.map_error(corrupt)
  }
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
