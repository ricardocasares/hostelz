//// Application use case: remove a member from an organization. Refuses removing
//// the last Owner (`LastOwner`).

import domain/membership
import domain/membership_repo.{type MembershipRepo}
import domain/organization.{type OrganizationId}
import domain/role
import domain/role_repo.{type RoleRepo}
import domain/user
import gleam/javascript/promise.{type Promise}
import gleam/result
import gleam/string

pub type RemoveMemberError {
  InvalidUserId(user.UserError)
  NotMember
  LastOwner
  RepoFailed(String)
}

pub fn run(
  membership_repo: MembershipRepo,
  role_repo: RoleRepo,
  organization_id: OrganizationId,
  raw_user_id: String,
) -> Promise(Result(Nil, RemoveMemberError)) {
  case user.new_id(raw_user_id) {
    Error(e) -> promise.resolve(Error(InvalidUserId(e)))
    Ok(user_id) -> {
      use found <- promise.await(membership_repo.find(organization_id, user_id))
      case found {
        Error(membership_repo.NotFound) -> promise.resolve(Error(NotMember))
        Error(other) -> promise.resolve(Error(RepoFailed(string.inspect(other))))
        Ok(member) ->
          guard(membership_repo, role_repo, organization_id, user_id, member)
      }
    }
  }
}

fn guard(
  membership_repo: MembershipRepo,
  role_repo: RoleRepo,
  organization_id: OrganizationId,
  user_id: user.UserId,
  member: membership.Membership,
) -> Promise(Result(Nil, RemoveMemberError)) {
  use role_found <- promise.await(role_repo.find(membership.role_id(member)))
  case role_found {
    Error(e) -> promise.resolve(Error(RepoFailed(string.inspect(e))))
    Ok(r) ->
      case role.is_owner(r) {
        False -> delete(membership_repo, organization_id, user_id)
        True -> {
          use count <- promise.await(membership_repo.count_owners(organization_id))
          case count {
            Error(e) -> promise.resolve(Error(RepoFailed(string.inspect(e))))
            Ok(n) if n <= 1 -> promise.resolve(Error(LastOwner))
            Ok(_) -> delete(membership_repo, organization_id, user_id)
          }
        }
      }
  }
}

fn delete(
  membership_repo: MembershipRepo,
  organization_id: OrganizationId,
  user_id: user.UserId,
) -> Promise(Result(Nil, RemoveMemberError)) {
  use deleted <- promise.map(membership_repo.delete(organization_id, user_id))
  deleted |> result.map_error(fn(e) { RepoFailed(string.inspect(e)) })
}
