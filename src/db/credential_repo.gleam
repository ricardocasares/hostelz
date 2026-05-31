//// Postgres-backed adapter for the credential port (a user's password hash).

import brioche/sql as db
import db/sql as queries
import domain/credential_repo.{
  type CredentialRepo, type RepoError, CredentialRepo, NotFound, StorageError,
}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> CredentialRepo {
  CredentialRepo(
    save: fn(uid, hash) { save(conn, uid, hash) },
    find_hash: fn(uid) { find_hash(conn, uid) },
  )
}

fn save(
  conn: db.Connection,
  uid: UserId,
  hash: String,
) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.insert_credential(conn, user.user_id(uid), hash))
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn find_hash(
  conn: db.Connection,
  uid: UserId,
) -> Promise(Result(String, RepoError)) {
  use res <- promise.map(queries.find_credential_by_user(conn, user.user_id(uid)))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) -> Ok(row.password_hash)
  }
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
