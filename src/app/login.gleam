//// Application use case: exchange email + password for a session token.
//// Returns the raw token (shown once) and the user. Unknown email and wrong
//// password both yield `InvalidCredentials` — no account enumeration.

import auth/password
import auth/token
import domain/credential_repo.{type CredentialRepo}
import domain/email
import domain/repo_error.{type RepoError}
import domain/session_repo.{type SessionRepo}
import domain/user.{type User}
import domain/user_repo.{type UserRepo}
import gleam/javascript/promise.{type Promise}

pub type LoginError {
  InvalidCredentials
  RepoFailed(RepoError)
}

pub fn run(
  user_repo: UserRepo,
  credential_repo: CredentialRepo,
  session_repo: SessionRepo,
  generate_token: fn() -> String,
  raw_email: String,
  raw_password: String,
) -> Promise(Result(#(String, User), LoginError)) {
  case email.new(raw_email) {
    Error(_) -> promise.resolve(Error(InvalidCredentials))
    Ok(address) -> {
      use found <- promise.await(user_repo.find_by_email(address))
      case found {
        Error(_) -> promise.resolve(Error(InvalidCredentials))
        Ok(user) ->
          verify_and_issue(
            session_repo,
            credential_repo,
            generate_token,
            user,
            raw_password,
          )
      }
    }
  }
}

fn verify_and_issue(
  session_repo: SessionRepo,
  credential_repo: CredentialRepo,
  generate_token: fn() -> String,
  user: User,
  raw_password: String,
) -> Promise(Result(#(String, User), LoginError)) {
  use credential <- promise.await(credential_repo.find_hash(user.id(user)))
  case credential {
    Error(_) -> promise.resolve(Error(InvalidCredentials))
    Ok(hash) -> {
      use ok <- promise.await(password.verify(raw_password, hash))
      case ok {
        False -> promise.resolve(Error(InvalidCredentials))
        True -> {
          let raw = generate_token()
          use saved <- promise.map(session_repo.save(
            token.hash(raw),
            user.id(user),
          ))
          case saved {
            Ok(Nil) -> Ok(#(raw, user))
            Error(e) -> Error(RepoFailed(e))
          }
        }
      }
    }
  }
}
