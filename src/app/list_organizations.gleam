//// Application use case: list all organizations.

import domain/organization.{type Organization}
import domain/organization_repo.{type OrganizationRepo, type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListOrganizationsError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: OrganizationRepo,
) -> Promise(Result(List(Organization), ListOrganizationsError)) {
  use result <- promise.map(repo.list_all())
  result |> result.map_error(RepoFailed)
}
