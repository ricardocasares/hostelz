//// Application use case: register a guest.
////
//// Validates raw input through the domain smart constructors, then persists the
//// guest via the repository port. Mirrors the katas' `place_order`: each layer's
//// failure is wrapped in its own variant, so a caller can tell invalid input
//// (a domain error) apart from a storage failure.

import domain/email
import domain/guest.{type Guest}
import domain/guest_repo.{type GuestRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type RegisterGuestError {
  InvalidGuest(guest.GuestError)
  InvalidEmail(email.EmailError)
  RepoFailed(RepoError)
}

/// Mint an id with `generate_id`, validate `name` and `raw_email`, build a
/// `Guest`, and save it. Returns the stored guest on success. The id generator
/// is injected (rather than called here directly) so the use case stays pure to
/// test — pass a fixed stub in tests, a real nanoid generator in production.
pub fn run(
  repo: GuestRepo,
  generate_id: fn() -> String,
  name: String,
  raw_email: String,
) -> Promise(Result(Guest, RegisterGuestError)) {
  case build(generate_id(), name, raw_email) {
    Error(error) -> promise.resolve(Error(error))
    Ok(new_guest) -> {
      use saved <- promise.map(repo.save(new_guest))
      saved
      |> result.replace(new_guest)
      |> result.map_error(RepoFailed)
    }
  }
}

/// Pure validation: turn raw strings into a valid `Guest` or a wrapped domain
/// error. No IO — kept separate from `run` so the rules are trivially testable.
fn build(
  id: String,
  name: String,
  raw_email: String,
) -> Result(Guest, RegisterGuestError) {
  use gid <- result.try(guest.new_id(id) |> result.map_error(InvalidGuest))
  use address <- result.try(
    email.new(raw_email) |> result.map_error(InvalidEmail),
  )
  guest.new(gid, name, address) |> result.map_error(InvalidGuest)
}
