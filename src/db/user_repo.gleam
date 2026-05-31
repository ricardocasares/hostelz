//// Postgres-backed adapter for the user persistence port. Mirrors
//// `db/organization_repo`: generated squirrel queries over a brioche
//// connection, rows rebuilt through the domain smart constructors. Email
//// uniqueness is enforced by the database (`users_email_key`) and surfaced as
//// `Conflict`.

import brioche/sql as db
import db/sql as queries
import domain/email.{type Email}
import domain/repo_error.{
  type RepoError, Conflict, Corrupt, NotFound, StorageError,
}
import domain/user.{type User, type UserId}
import domain/user_repo.{type UserRepo, UserRepo}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> UserRepo {
  UserRepo(
    save: fn(u) { save(conn, u) },
    find: fn(id) { find(conn, id) },
    find_by_email: fn(e) { find_by_email(conn, e) },
    list_all: fn() { list_all(conn) },
  )
}

fn save(conn: db.Connection, u: User) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.insert_user(
    conn,
    user.user_id(user.id(u)),
    email.to_string(user.email(u)),
    user.name(u),
  ))
  res
  |> result.replace(Nil)
  |> result.map_error(save_error)
}

fn find(conn: db.Connection, id: UserId) -> Promise(Result(User, RepoError)) {
  use res <- promise.map(queries.find_user_by_id(conn, user.user_id(id)))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(row.id, row.email, row.name)
  }
}

fn find_by_email(
  conn: db.Connection,
  e: Email,
) -> Promise(Result(User, RepoError)) {
  use res <- promise.map(queries.find_user_by_email(conn, email.to_string(e)))
  case res {
    Error(err) -> Error(storage_error(err))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(row.id, row.email, row.name)
  }
}

fn list_all(conn: db.Connection) -> Promise(Result(List(User), RepoError)) {
  use res <- promise.map(queries.list_users(conn))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) { reconstruct(row.id, row.email, row.name) })
  }
}

/// Rebuild a `User` from stored column values. Exposed for unit testing.
pub fn reconstruct(
  id: String,
  mail: String,
  name: String,
) -> Result(User, RepoError) {
  use uid <- result.try(user.new_id(id) |> result.map_error(corrupt))
  use address <- result.try(email.new(mail) |> result.map_error(corrupt))
  user.new(uid, address, name) |> result.map_error(corrupt)
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn save_error(error: db.SqlError) -> RepoError {
  case error {
    db.ConstraintViolated(constraint: "users_email_key", ..) ->
      Conflict("email already registered")
    _ -> storage_error(error)
  }
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
