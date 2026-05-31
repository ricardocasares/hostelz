//// Application use case: list the guests belonging to one organization.
////
//// The guest list is per-tenant: it asks the repository for every guest of the
//// given organization and wraps a storage failure in its own variant, so the
//// HTTP boundary maps use-case errors onto status codes without knowing about
//// the repo.

import domain/guest.{type Guest}
import domain/guest_repo.{type GuestRepo, type RepoError}
import domain/organization.{type OrganizationId}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListOrganizationGuestsError {
  RepoFailed(RepoError)
}

/// Fetch the organization's guests (newest first — the query's order), wrapping
/// a storage failure as `RepoFailed`.
pub fn run(
  repo: GuestRepo,
  organization_id: OrganizationId,
) -> Promise(Result(List(Guest), ListOrganizationGuestsError)) {
  use result <- promise.map(repo.list_by_organization(organization_id))
  result |> result.map_error(RepoFailed)
}
