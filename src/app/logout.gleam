//// Application use case: revoke a session. Idempotent — deleting an unknown
//// token hash is fine.

import auth/token
import domain/repo_error.{type RepoError}
import domain/session_repo.{type SessionRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type LogoutError {
  RepoFailed(RepoError)
}

pub fn run(
  session_repo: SessionRepo,
  raw_token: String,
) -> Promise(Result(Nil, LogoutError)) {
  use deleted <- promise.map(session_repo.delete(token.hash(raw_token)))
  deleted |> result.map_error(fn(e) { RepoFailed(e) })
}
