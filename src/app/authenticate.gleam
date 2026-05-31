//// Application use case: resolve a raw Bearer token to the authenticated user.
//// Used by the `require_auth` middleware. Hashes the token, looks up the
//// unexpired session, then loads the user. Any miss is `InvalidSession`.

import auth/token
import domain/session_repo.{type SessionRepo}
import domain/user.{type User}
import domain/user_repo.{type UserRepo}
import gleam/javascript/promise.{type Promise}
import gleam/string

pub type AuthError {
  InvalidSession
  RepoFailed(String)
}

pub fn run(
  session_repo: SessionRepo,
  user_repo: UserRepo,
  raw_token: String,
) -> Promise(Result(User, AuthError)) {
  use found <- promise.await(session_repo.find_user(token.hash(raw_token)))
  case found {
    Error(session_repo.NotFound) -> promise.resolve(Error(InvalidSession))
    Error(other) -> promise.resolve(Error(RepoFailed(string.inspect(other))))
    Ok(user_id) -> {
      use user <- promise.map(user_repo.find(user_id))
      case user {
        Ok(u) -> Ok(u)
        // A session pointing at a missing user is treated as invalid.
        Error(_) -> Error(InvalidSession)
      }
    }
  }
}
