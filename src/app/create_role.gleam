//// Application use case: create a custom role in an organization. Permissions
//// are already-parsed `Permission` values (the boundary rejects unknown
//// permission strings). Duplicate role name per org → `NameTaken`.

import domain/organization.{type OrganizationId}
import domain/permission.{type Permission}
import domain/repo_error.{type RepoError}
import domain/role.{type Role}
import domain/role_repo.{type RoleRepo}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type CreateRoleError {
  InvalidRole(role.RoleError)
  NameTaken
  RepoFailed(RepoError)
}

pub fn run(
  repo: RoleRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  name: String,
  permissions: List(Permission),
) -> Promise(Result(Role, CreateRoleError)) {
  case build(generate_id(), organization_id, name, permissions) {
    Error(error) -> promise.resolve(Error(error))
    Ok(new_role) -> {
      use saved <- promise.map(repo.save(new_role))
      case saved {
        Ok(Nil) -> Ok(new_role)
        Error(repo_error.Conflict(_)) -> Error(NameTaken)
        Error(other) -> Error(RepoFailed(other))
      }
    }
  }
}

fn build(
  id: String,
  organization_id: OrganizationId,
  name: String,
  permissions: List(Permission),
) -> Result(Role, CreateRoleError) {
  use rid <- result.try(role.new_id(id) |> result.map_error(InvalidRole))
  role.new(rid, organization_id, name, permissions)
  |> result.map_error(InvalidRole)
}
