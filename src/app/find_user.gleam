//// Application use case: find a user by id. A "no such user" repo failure is
//// lifted to its own `NotFound` variant so the HTTP boundary can answer 404.

import domain/user.{type User}
import domain/user_repo.{type UserRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type FindUserError {
  InvalidId(user.UserError)
  NotFound
  RepoFailed(RepoError)
}

pub fn run(
  repo: UserRepo,
  raw_id: String,
) -> Promise(Result(User, FindUserError)) {
  case user.new_id(raw_id) {
    Error(error) -> promise.resolve(Error(InvalidId(error)))
    Ok(id) -> {
      use result <- promise.map(repo.find(id))
      result |> result.map_error(to_error)
    }
  }
}

fn to_error(error: RepoError) -> FindUserError {
  case error {
    user_repo.NotFound -> NotFound
    other -> RepoFailed(other)
  }
}
