//// Postgres-backed adapter for the session port. Only the token hash is
//// stored; `find_user` relies on the SQL `expires_at > now()` filter so an
//// expired session simply returns no row (`NotFound`).

import brioche/sql as db
import db/sql as queries
import domain/session_repo.{
  type RepoError, type SessionRepo, Corrupt, NotFound, SessionRepo, StorageError,
}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> SessionRepo {
  SessionRepo(
    save: fn(token_hash, uid) { save(conn, token_hash, uid) },
    find_user: fn(token_hash) { find_user(conn, token_hash) },
    delete: fn(token_hash) { delete(conn, token_hash) },
  )
}

fn save(
  conn: db.Connection,
  token_hash: String,
  uid: UserId,
) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.insert_session(conn, token_hash, user.user_id(uid)))
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn find_user(
  conn: db.Connection,
  token_hash: String,
) -> Promise(Result(UserId, RepoError)) {
  use res <- promise.map(queries.find_session_user_by_token_hash(conn, token_hash))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      user.new_id(row.user_id) |> result.map_error(corrupt)
  }
}

fn delete(
  conn: db.Connection,
  token_hash: String,
) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.delete_session_by_token_hash(conn, token_hash))
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
