//// Application use case: list the direct children of a space.

import domain/space.{type Space, type SpaceId}
import domain/space_repo.{type RepoError, type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListChildSpacesError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: SpaceRepo,
  parent_id: SpaceId,
) -> Promise(Result(List(Space), ListChildSpacesError)) {
  use result <- promise.map(repo.list_children(parent_id))
  result |> result.map_error(RepoFailed)
}
