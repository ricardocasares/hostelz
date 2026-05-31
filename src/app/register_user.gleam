//// Application use case: register a user (a system account) with a password.
////
//// Validates email/name/password, saves the `User` (email uniqueness enforced
//// by the DB → `EmailTaken`), then hashes the password and stores the
//// credential separately. Email uniqueness is authoritative at the DB.

import auth/password
import domain/credential_repo.{type CredentialRepo}
import domain/email
import domain/repo_error.{type RepoError}
import domain/user.{type User}
import domain/user_repo.{type UserRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type RegisterUserError {
  InvalidUser(user.UserError)
  InvalidEmail(email.EmailError)
  InvalidPassword(password.PasswordError)
  EmailTaken
  RepoFailed(RepoError)
}

pub fn run(
  user_repo: UserRepo,
  credential_repo: CredentialRepo,
  generate_id: fn() -> String,
  raw_email: String,
  name: String,
  raw_password: String,
) -> Promise(Result(User, RegisterUserError)) {
  case build(generate_id(), raw_email, name, raw_password) {
    Error(error) -> promise.resolve(Error(error))
    Ok(new_user) -> {
      use saved <- promise.await(user_repo.save(new_user))
      case saved {
        Error(repo_error.Conflict(_)) -> promise.resolve(Error(EmailTaken))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(Nil) -> store_credential(credential_repo, new_user, raw_password)
      }
    }
  }
}

fn store_credential(
  credential_repo: CredentialRepo,
  new_user: User,
  raw_password: String,
) -> Promise(Result(User, RegisterUserError)) {
  use hash <- promise.await(password.hash(raw_password))
  use saved <- promise.map(credential_repo.save(user.id(new_user), hash))
  saved |> result.replace(new_user) |> result.map_error(RepoFailed)
}

/// Pure validation, password policy included, before any IO.
fn build(
  id: String,
  raw_email: String,
  name: String,
  raw_password: String,
) -> Result(User, RegisterUserError) {
  use _ <- result.try(
    password.validate(raw_password) |> result.map_error(InvalidPassword),
  )
  use uid <- result.try(user.new_id(id) |> result.map_error(InvalidUser))
  use address <- result.try(
    email.new(raw_email) |> result.map_error(InvalidEmail),
  )
  user.new(uid, address, name) |> result.map_error(InvalidUser)
}
