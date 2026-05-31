//// Application use case: list an organization's roles.

import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/role.{type Role}
import domain/role_repo.{type RoleRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListRolesError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: RoleRepo,
  organization_id: OrganizationId,
) -> Promise(Result(List(Role), ListRolesError)) {
  use result <- promise.map(repo.list_by_organization(organization_id))
  result |> result.map_error(RepoFailed)
}
