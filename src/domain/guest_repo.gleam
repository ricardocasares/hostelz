//// The persistence *port* for guests: a record of functions the application
//// depends on, with no knowledge of how guests are stored. Adapters — such as
//// `db/guest_repo`, backed by Postgres — build a value of this type, so the
//// domain and use cases never import a database library.

import domain/guest.{type Guest, type GuestId}
import gleam/javascript/promise.{type Promise}

pub type RepoError {
  /// No guest exists for the given id.
  NotFound
  /// A stored row could not be turned back into a valid `Guest`: it failed the
  /// domain's own validation on load (a corrupt or legacy row).
  Corrupt(String)
  /// The storage backend itself failed (connection, query, constraint, ...).
  StorageError(String)
}

/// The guest repository, as a record of functions. Build one with an adapter
/// such as `db/guest_repo.new`. Every operation is async (`Promise`) because the
/// only adapter so far talks to Postgres over Bun's SQL client.
pub type GuestRepo {
  GuestRepo(
    save: fn(Guest) -> Promise(Result(Nil, RepoError)),
    find: fn(GuestId) -> Promise(Result(Guest, RepoError)),
    list_all: fn() -> Promise(Result(List(Guest), RepoError)),
  )
}
