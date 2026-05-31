//// Application use case: register a guest.
////
//// Validates raw input through the domain smart constructors, then persists the
//// guest via the repository port. Mirrors the katas' `place_order`: each layer's
//// failure is wrapped in its own variant, so a caller can tell invalid input
//// (a domain error) apart from a storage failure.

import domain/email
import domain/guest.{type Guest}
import domain/guest_repo.{type GuestRepo}
import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option}
import gleam/result

pub type RegisterGuestError {
  InvalidGuest(guest.GuestError)
  InvalidEmail(email.EmailError)
  RepoFailed(RepoError)
}

/// Mint an id with `generate_id`, validate `name` and `raw_email`, build a
/// `Guest` belonging to `organization_id` (optionally linked to `user_id`), and
/// save it. The owning org and the optional user link are already-validated
/// value objects supplied by the boundary; a `None` user is a walk-in. The id
/// generator is injected so the use case stays pure to test.
pub fn run(
  repo: GuestRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  user_id: Option(UserId),
  name: String,
  raw_email: String,
) -> Promise(Result(Guest, RegisterGuestError)) {
  case build(generate_id(), organization_id, user_id, name, raw_email) {
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
  organization_id: OrganizationId,
  user_id: Option(UserId),
  name: String,
  raw_email: String,
) -> Result(Guest, RegisterGuestError) {
  use gid <- result.try(guest.new_id(id) |> result.map_error(InvalidGuest))
  use address <- result.try(
    email.new(raw_email) |> result.map_error(InvalidEmail),
  )
  guest.new(gid, organization_id, user_id, name, address)
  |> result.map_error(InvalidGuest)
}
