//// Persistence port for roles. `save` persists a role together with its
//// permission set; `find` loads both back.

import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/role.{type Role, type RoleId}
import gleam/javascript/promise.{type Promise}

pub type RoleRepo {
  RoleRepo(
    save: fn(Role) -> Promise(Result(Nil, RepoError)),
    find: fn(RoleId) -> Promise(Result(Role, RepoError)),
    list_by_organization: fn(OrganizationId) ->
      Promise(Result(List(Role), RepoError)),
    delete: fn(RoleId) -> Promise(Result(Nil, RepoError)),
  )
}
