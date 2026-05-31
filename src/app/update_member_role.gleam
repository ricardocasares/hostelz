//// Application use case: change a member's role. Refuses demoting the last
//// Owner of the organization (`LastOwner`).

import domain/membership.{type Membership}
import domain/membership_repo.{type MembershipRepo}
import domain/organization.{type OrganizationId}
import domain/role.{type Role}
import domain/role_repo.{type RoleRepo}
import domain/user
import gleam/javascript/promise.{type Promise}
import gleam/string

pub type UpdateMemberError {
  InvalidUserId(user.UserError)
  InvalidRoleId(role.RoleError)
  RoleNotFound
  NotMember
  LastOwner
  RepoFailed(String)
}

pub fn run(
  membership_repo: MembershipRepo,
  role_repo: RoleRepo,
  organization_id: OrganizationId,
  raw_user_id: String,
  raw_role_id: String,
) -> Promise(Result(Membership, UpdateMemberError)) {
  case user.new_id(raw_user_id), role.new_id(raw_role_id) {
    Error(e), _ -> promise.resolve(Error(InvalidUserId(e)))
    _, Error(e) -> promise.resolve(Error(InvalidRoleId(e)))
    Ok(user_id), Ok(role_id) -> {
      use role_found <- promise.await(role_repo.find(role_id))
      case role_found {
        Error(_) -> promise.resolve(Error(RoleNotFound))
        Ok(new_role) ->
          case role.organization_id(new_role) == organization_id {
            False -> promise.resolve(Error(RoleNotFound))
            True ->
              change(membership_repo, role_repo, organization_id, user_id, new_role)
          }
      }
    }
  }
}

fn change(
  membership_repo: MembershipRepo,
  role_repo: RoleRepo,
  organization_id: OrganizationId,
  user_id: user.UserId,
  new_role: Role,
) -> Promise(Result(Membership, UpdateMemberError)) {
  use found <- promise.await(membership_repo.find(organization_id, user_id))
  case found {
    Error(membership_repo.NotFound) -> promise.resolve(Error(NotMember))
    Error(other) -> promise.resolve(Error(RepoFailed(string.inspect(other))))
    Ok(member) -> {
      use current <- promise.await(role_repo.find(membership.role_id(member)))
      case current {
        Error(e) -> promise.resolve(Error(RepoFailed(string.inspect(e))))
        Ok(cur) ->
          case role.is_owner(cur) && !role.is_owner(new_role) {
            True ->
              guard_last_owner(membership_repo, organization_id, member, new_role)
            False -> save(membership_repo, member, new_role)
          }
      }
    }
  }
}

fn guard_last_owner(
  membership_repo: MembershipRepo,
  organization_id: OrganizationId,
  member: Membership,
  new_role: Role,
) -> Promise(Result(Membership, UpdateMemberError)) {
  use count <- promise.await(membership_repo.count_owners(organization_id))
  case count {
    Error(e) -> promise.resolve(Error(RepoFailed(string.inspect(e))))
    Ok(n) if n <= 1 -> promise.resolve(Error(LastOwner))
    Ok(_) -> save(membership_repo, member, new_role)
  }
}

fn save(
  membership_repo: MembershipRepo,
  member: Membership,
  new_role: Role,
) -> Promise(Result(Membership, UpdateMemberError)) {
  let updated = membership.assign_role(member, role.id(new_role))
  use saved <- promise.map(membership_repo.save(updated))
  case saved {
    Ok(Nil) -> Ok(updated)
    Error(e) -> Error(RepoFailed(string.inspect(e)))
  }
}
