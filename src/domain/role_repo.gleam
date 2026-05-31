//// Persistence port for roles. `save` persists a role together with its
//// permission set; `find` loads both back.

import domain/organization.{type OrganizationId}
import domain/role.{type Role, type RoleId}
import gleam/javascript/promise.{type Promise}

pub type RepoError {
  NotFound
  /// Unique constraint (duplicate role name in the org) or a role still in use.
  Conflict(String)
  Corrupt(String)
  StorageError(String)
}

pub type RoleRepo {
  RoleRepo(
    save: fn(Role) -> Promise(Result(Nil, RepoError)),
    find: fn(RoleId) -> Promise(Result(Role, RepoError)),
    list_by_organization: fn(OrganizationId) ->
      Promise(Result(List(Role), RepoError)),
    delete: fn(RoleId) -> Promise(Result(Nil, RepoError)),
  )
}
