//// Application use case: set a space's bookability. Toggling never invalidates
//// existing bookings (it only gates new ones), so no booking guard is needed.

import domain/repo_error.{type RepoError}
import domain/space.{type Space}
import domain/space_repo.{type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type SetSpaceBookableError {
  InvalidId(space.SpaceError)
  NotFound
  RepoFailed(RepoError)
}

pub fn run(
  repo: SpaceRepo,
  raw_id: String,
  bookable: Bool,
) -> Promise(Result(Space, SetSpaceBookableError)) {
  case space.new_id(raw_id) {
    Error(error) -> promise.resolve(Error(InvalidId(error)))
    Ok(sid) -> {
      use found <- promise.await(repo.find(sid))
      case found {
        Error(repo_error.NotFound) -> promise.resolve(Error(NotFound))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(sp) -> {
          let updated = space.set_bookable(sp, bookable)
          use saved <- promise.map(repo.save(updated))
          saved |> result.replace(updated) |> result.map_error(RepoFailed)
        }
      }
    }
  }
}
