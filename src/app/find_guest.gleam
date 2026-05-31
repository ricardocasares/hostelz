//// Application use case: find a guest by id.
////
//// A read-only counterpart to `register_guest`. The raw id from the URL is run
//// through the domain smart constructor first (so a blank id is rejected before
//// touching the database), then handed to the repository. A "no such guest"
//// repo failure is lifted to its own `NotFound` variant so the HTTP boundary
//// can answer 404, distinct from a genuine storage failure (500).

import domain/guest.{type Guest}
import domain/guest_repo.{type GuestRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type FindGuestError {
  InvalidId(guest.GuestError)
  NotFound
  RepoFailed(RepoError)
}

/// Validate `raw_id`, then fetch the matching guest. Returns `NotFound` when no
/// guest has that id, `InvalidId` when the id itself is malformed, and
/// `RepoFailed` for any other storage failure.
pub fn run(
  repo: GuestRepo,
  raw_id: String,
) -> Promise(Result(Guest, FindGuestError)) {
  case guest.new_id(raw_id) {
    Error(error) -> promise.resolve(Error(InvalidId(error)))
    Ok(id) -> {
      use result <- promise.map(repo.find(id))
      result |> result.map_error(to_error)
    }
  }
}

fn to_error(error: RepoError) -> FindGuestError {
  case error {
    guest_repo.NotFound -> NotFound
    other -> RepoFailed(other)
  }
}
