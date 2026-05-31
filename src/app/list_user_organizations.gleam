//// Application use case: the organizations the current user belongs to.

import domain/organization.{type Organization}
import domain/organization_repo.{type OrganizationRepo, type RepoError}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListUserOrganizationsError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: OrganizationRepo,
  user_id: UserId,
) -> Promise(Result(List(Organization), ListUserOrganizationsError)) {
  use result <- promise.map(repo.list_for_user(user_id))
  result |> result.map_error(RepoFailed)
}
