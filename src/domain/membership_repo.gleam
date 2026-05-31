//// Persistence port for memberships. `count_owners` (memberships whose role is
//// the owner role) backs the "can't remove/demote the last Owner" guard.

import domain/membership.{type Membership}
import domain/organization.{type OrganizationId}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}

pub type RepoError {
  NotFound
  Conflict(String)
  Corrupt(String)
  StorageError(String)
}

pub type MembershipRepo {
  MembershipRepo(
    save: fn(Membership) -> Promise(Result(Nil, RepoError)),
    find: fn(OrganizationId, UserId) -> Promise(Result(Membership, RepoError)),
    list_by_organization: fn(OrganizationId) ->
      Promise(Result(List(Membership), RepoError)),
    delete: fn(OrganizationId, UserId) -> Promise(Result(Nil, RepoError)),
    count_owners: fn(OrganizationId) -> Promise(Result(Int, RepoError)),
  )
}
