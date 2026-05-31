//// Application use case: rename a role and replace its permission set. The
//// system Owner role is immutable (`CannotEditOwner`).

import domain/organization.{type OrganizationId}
import domain/permission.{type Permission}
import domain/role.{type Role}
import domain/role_repo.{type RoleRepo}
import gleam/javascript/promise.{type Promise}
import gleam/string

pub type UpdateRoleError {
  InvalidId(role.RoleError)
  NotFound
  CannotEditOwner
  InvalidName(role.RoleError)
  NameTaken
  RepoFailed(String)
}

pub fn run(
  repo: RoleRepo,
  organization_id: OrganizationId,
  raw_role_id: String,
  name: String,
  permissions: List(Permission),
) -> Promise(Result(Role, UpdateRoleError)) {
  case role.new_id(raw_role_id) {
    Error(e) -> promise.resolve(Error(InvalidId(e)))
    Ok(rid) -> {
      use found <- promise.await(repo.find(rid))
      case found {
        Error(role_repo.NotFound) -> promise.resolve(Error(NotFound))
        Error(other) -> promise.resolve(Error(RepoFailed(string.inspect(other))))
        // A role from another org is "not found" through this org's path.
        Ok(existing) ->
          case role.organization_id(existing) == organization_id {
            False -> promise.resolve(Error(NotFound))
            True -> apply(repo, existing, name, permissions)
          }
      }
    }
  }
}

fn apply(
  repo: RoleRepo,
  existing: Role,
  name: String,
  permissions: List(Permission),
) -> Promise(Result(Role, UpdateRoleError)) {
  case role.is_owner(existing) {
    True -> promise.resolve(Error(CannotEditOwner))
    False ->
      case role.rename(existing, name) {
        Error(e) -> promise.resolve(Error(InvalidName(e)))
        Ok(renamed) -> {
          let updated = role.set_permissions(renamed, permissions)
          use saved <- promise.map(repo.save(updated))
          case saved {
            Ok(Nil) -> Ok(updated)
            Error(role_repo.Conflict(_)) -> Error(NameTaken)
            Error(other) -> Error(RepoFailed(string.inspect(other)))
          }
        }
      }
  }
}
