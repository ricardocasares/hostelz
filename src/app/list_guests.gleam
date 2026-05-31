//// Application use case: list all guests.
////
//// A read-only counterpart to `register_guest`: it asks the repository for
//// every guest and wraps a storage failure in its own variant, so the HTTP
//// boundary maps use-case errors onto status codes without knowing about the
//// repo. There is no invalid-input path here — listing takes no arguments.

import domain/guest.{type Guest}
import domain/guest_repo.{type GuestRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListGuestsError {
  RepoFailed(RepoError)
}

/// Fetch all guests via the repository (newest first — the query's order),
/// wrapping a storage failure as `RepoFailed`.
pub fn run(repo: GuestRepo) -> Promise(Result(List(Guest), ListGuestsError)) {
  use result <- promise.map(repo.list_all())
  result |> result.map_error(RepoFailed)
}
