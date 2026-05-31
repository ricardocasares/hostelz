//// Application use case: add an existing user (by email) to an organization
//// with a role. The role must belong to the org; the email must be a known
//// user; an existing member is `AlreadyMember` (use update to change a role).

import domain/email
import domain/membership.{type Membership}
import domain/membership_repo.{type MembershipRepo}
import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/role
import domain/role_repo.{type RoleRepo}
import domain/user
import domain/user_repo.{type UserRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type AddMemberError {
  InvalidEmail(email.EmailError)
  InvalidRoleId(role.RoleError)
  RoleNotFound
  UserNotFound
  AlreadyMember
  RepoFailed(RepoError)
}

pub fn run(
  membership_repo: MembershipRepo,
  role_repo: RoleRepo,
  user_repo: UserRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  raw_email: String,
  raw_role_id: String,
) -> Promise(Result(Membership, AddMemberError)) {
  case email.new(raw_email), role.new_id(raw_role_id) {
    Error(e), _ -> promise.resolve(Error(InvalidEmail(e)))
    _, Error(e) -> promise.resolve(Error(InvalidRoleId(e)))
    Ok(address), Ok(role_id) -> {
      use role_found <- promise.await(role_repo.find(role_id))
      case role_found {
        Error(_) -> promise.resolve(Error(RoleNotFound))
        Ok(r) ->
          case role.organization_id(r) == organization_id {
            False -> promise.resolve(Error(RoleNotFound))
            True ->
              resolve_user(
                membership_repo,
                user_repo,
                generate_id,
                organization_id,
                address,
                role_id,
              )
          }
      }
    }
  }
}

fn resolve_user(
  membership_repo: MembershipRepo,
  user_repo: UserRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  address: email.Email,
  role_id: role.RoleId,
) -> Promise(Result(Membership, AddMemberError)) {
  use found <- promise.await(user_repo.find_by_email(address))
  case found {
    Error(_) -> promise.resolve(Error(UserNotFound))
    Ok(u) ->
      add(membership_repo, generate_id, organization_id, user.id(u), role_id)
  }
}

fn add(
  membership_repo: MembershipRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  user_id: user.UserId,
  role_id: role.RoleId,
) -> Promise(Result(Membership, AddMemberError)) {
  use existing <- promise.await(membership_repo.find(organization_id, user_id))
  case existing {
    Ok(_) -> promise.resolve(Error(AlreadyMember))
    Error(repo_error.NotFound) -> {
      let assert Ok(id) = membership.new_id(generate_id())
      let member = membership.new(id, organization_id, user_id, role_id)
      use saved <- promise.map(membership_repo.save(member))
      saved |> result.replace(member) |> result.map_error(RepoFailed)
    }
    Error(other) -> promise.resolve(Error(RepoFailed(other)))
  }
}
