//// Application use case: delete a custom role. The Owner role can't be deleted
//// (`CannotDeleteOwner`); a role still assigned to a member can't either
//// (`RoleInUse`, surfaced from the FK). A role from another organization is
//// "not found" through this org's path.

import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/role
import domain/role_repo.{type RoleRepo}
import gleam/javascript/promise.{type Promise}

pub type DeleteRoleError {
  InvalidId(role.RoleError)
  NotFound
  CannotDeleteOwner
  RoleInUse
  RepoFailed(RepoError)
}

pub fn run(
  repo: RoleRepo,
  organization_id: OrganizationId,
  raw_role_id: String,
) -> Promise(Result(Nil, DeleteRoleError)) {
  case role.new_id(raw_role_id) {
    Error(e) -> promise.resolve(Error(InvalidId(e)))
    Ok(rid) -> {
      use found <- promise.await(repo.find(rid))
      case found {
        Error(repo_error.NotFound) -> promise.resolve(Error(NotFound))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(existing) ->
          case role.organization_id(existing) == organization_id {
            False -> promise.resolve(Error(NotFound))
            True -> guard(repo, rid, existing)
          }
      }
    }
  }
}

fn guard(
  repo: RoleRepo,
  rid: role.RoleId,
  existing: role.Role,
) -> Promise(Result(Nil, DeleteRoleError)) {
  case role.is_owner(existing) {
    True -> promise.resolve(Error(CannotDeleteOwner))
    False -> {
      use deleted <- promise.map(repo.delete(rid))
      case deleted {
        Ok(Nil) -> Ok(Nil)
        Error(repo_error.Conflict(_)) -> Error(RoleInUse)
        Error(other) -> Error(RepoFailed(other))
      }
    }
  }
}
