//// Application use case: list all users.

import domain/user.{type User}
import domain/user_repo.{type UserRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListUsersError {
  RepoFailed(RepoError)
}

pub fn run(repo: UserRepo) -> Promise(Result(List(User), ListUsersError)) {
  use result <- promise.map(repo.list_all())
  result |> result.map_error(RepoFailed)
}
