//// The persistence *port* for organizations: a record of functions the
//// application depends on, with no knowledge of how organizations are stored.
//// Adapters — such as `db/organization_repo`, backed by Postgres — build a
//// value of this type.

import domain/organization.{type Organization, type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/slug.{type Slug}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}

pub type OrganizationRepo {
  OrganizationRepo(
    save: fn(Organization) -> Promise(Result(Nil, RepoError)),
    find: fn(OrganizationId) -> Promise(Result(Organization, RepoError)),
    find_by_slug: fn(Slug) -> Promise(Result(Organization, RepoError)),
    list_all: fn() -> Promise(Result(List(Organization), RepoError)),
    /// Organizations the given user is a member of (joins memberships).
    list_for_user: fn(UserId) -> Promise(Result(List(Organization), RepoError)),
  )
}
