//// Application use case: does `user` hold `needed` in `organization_id`?
//// Loads the caller's membership, then its role, and applies `role.allows`
//// (Owner ⇒ every permission). Backs the `require_permission` guard.

import domain/membership
import domain/membership_repo.{type MembershipRepo}
import domain/organization.{type OrganizationId}
import domain/permission.{type Permission}
import domain/role
import domain/role_repo.{type RoleRepo}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/string

pub type AuthzError {
  NotMember
  Forbidden
  RepoFailed(String)
}

pub fn run(
  membership_repo: MembershipRepo,
  role_repo: RoleRepo,
  organization_id: OrganizationId,
  user_id: UserId,
  needed: Permission,
) -> Promise(Result(Nil, AuthzError)) {
  use found <- promise.await(membership_repo.find(organization_id, user_id))
  case found {
    Error(membership_repo.NotFound) -> promise.resolve(Error(NotMember))
    Error(other) -> promise.resolve(Error(RepoFailed(string.inspect(other))))
    Ok(member) -> {
      use role <- promise.map(role_repo.find(membership.role_id(member)))
      case role {
        Error(e) -> Error(RepoFailed(string.inspect(e)))
        Ok(r) ->
          case role.allows(r, needed) {
            True -> Ok(Nil)
            False -> Error(Forbidden)
          }
      }
    }
  }
}
