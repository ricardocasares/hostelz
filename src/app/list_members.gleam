//// Application use case: list an organization's memberships.

import domain/membership.{type Membership}
import domain/membership_repo.{type MembershipRepo, type RepoError}
import domain/organization.{type OrganizationId}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListMembersError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: MembershipRepo,
  organization_id: OrganizationId,
) -> Promise(Result(List(Membership), ListMembersError)) {
  use result <- promise.map(repo.list_by_organization(organization_id))
  result |> result.map_error(RepoFailed)
}
