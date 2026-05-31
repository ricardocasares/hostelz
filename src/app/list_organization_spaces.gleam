//// Application use case: list every space belonging to one organization
//// (a flat list; the caller assembles the tree from each space's parent_id).

import domain/organization.{type OrganizationId}
import domain/space.{type Space}
import domain/space_repo.{type RepoError, type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListOrganizationSpacesError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: SpaceRepo,
  organization_id: OrganizationId,
) -> Promise(Result(List(Space), ListOrganizationSpacesError)) {
  use result <- promise.map(repo.list_by_organization(organization_id))
  result |> result.map_error(RepoFailed)
}
