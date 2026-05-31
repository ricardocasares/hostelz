//// Application use case: register a user (a system account).
////
//// Mirrors `register_guest`: validate raw input through the domain smart
//// constructors, then persist. Email *uniqueness* is enforced by the database
//// (unique index) and surfaces as `RepoError.Conflict`, mapped to `EmailTaken`.

import domain/email
import domain/user.{type User}
import domain/user_repo.{type UserRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type RegisterUserError {
  InvalidUser(user.UserError)
  InvalidEmail(email.EmailError)
  EmailTaken
  RepoFailed(RepoError)
}

pub fn run(
  repo: UserRepo,
  generate_id: fn() -> String,
  raw_email: String,
  name: String,
) -> Promise(Result(User, RegisterUserError)) {
  case build(generate_id(), raw_email, name) {
    Error(error) -> promise.resolve(Error(error))
    Ok(new_user) -> {
      use saved <- promise.map(repo.save(new_user))
      saved
      |> result.replace(new_user)
      |> result.map_error(to_error)
    }
  }
}

fn build(
  id: String,
  raw_email: String,
  name: String,
) -> Result(User, RegisterUserError) {
  use uid <- result.try(user.new_id(id) |> result.map_error(InvalidUser))
  use address <- result.try(
    email.new(raw_email) |> result.map_error(InvalidEmail),
  )
  user.new(uid, address, name) |> result.map_error(InvalidUser)
}

fn to_error(error: RepoError) -> RegisterUserError {
  case error {
    user_repo.Conflict(_) -> EmailTaken
    other -> RepoFailed(other)
  }
}
