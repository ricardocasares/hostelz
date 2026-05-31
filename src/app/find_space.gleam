//// Application use case: find a space by id. A "no such space" repo failure is
//// lifted to its own `NotFound` variant so the HTTP boundary can answer 404.

import domain/repo_error.{type RepoError}
import domain/space.{type Space}
import domain/space_repo.{type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type FindSpaceError {
  InvalidId(space.SpaceError)
  NotFound
  RepoFailed(RepoError)
}

pub fn run(
  repo: SpaceRepo,
  raw_id: String,
) -> Promise(Result(Space, FindSpaceError)) {
  case space.new_id(raw_id) {
    Error(error) -> promise.resolve(Error(InvalidId(error)))
    Ok(id) -> {
      use result <- promise.map(repo.find(id))
      result |> result.map_error(to_error)
    }
  }
}

fn to_error(error: RepoError) -> FindSpaceError {
  case error {
    repo_error.NotFound -> NotFound
    other -> RepoFailed(other)
  }
}
