//// The persistence *port* for spaces: a record of functions the application
//// depends on, with no knowledge of how spaces are stored. Adapters — such as
//// `db/space_repo`, backed by Postgres — build a value of this type.

import domain/organization.{type OrganizationId}
import domain/space.{type Space, type SpaceId}
import gleam/javascript/promise.{type Promise}

pub type RepoError {
  /// No space exists for the given id.
  NotFound
  /// A stored row could not be turned back into a valid `Space`.
  Corrupt(String)
  /// The storage backend itself failed (connection, query, ...).
  StorageError(String)
}

pub type SpaceRepo {
  SpaceRepo(
    save: fn(Space) -> Promise(Result(Nil, RepoError)),
    find: fn(SpaceId) -> Promise(Result(Space, RepoError)),
    list_by_organization: fn(OrganizationId) ->
      Promise(Result(List(Space), RepoError)),
    list_children: fn(SpaceId) -> Promise(Result(List(Space), RepoError)),
  )
}
