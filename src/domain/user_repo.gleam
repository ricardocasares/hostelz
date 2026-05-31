//// The persistence *port* for users (system accounts): a record of functions
//// the application depends on, with no knowledge of how users are stored.
//// Adapters — such as `db/user_repo`, backed by Postgres — build a value of
//// this type.

import domain/email.{type Email}
import domain/user.{type User, type UserId}
import gleam/javascript/promise.{type Promise}

pub type RepoError {
  /// No user exists for the given id or email.
  NotFound
  /// A unique constraint was violated (the email is already registered).
  Conflict(String)
  /// A stored row could not be turned back into a valid `User`.
  Corrupt(String)
  /// The storage backend itself failed (connection, query, ...).
  StorageError(String)
}

pub type UserRepo {
  UserRepo(
    save: fn(User) -> Promise(Result(Nil, RepoError)),
    find: fn(UserId) -> Promise(Result(User, RepoError)),
    find_by_email: fn(Email) -> Promise(Result(User, RepoError)),
    list_all: fn() -> Promise(Result(List(User), RepoError)),
  )
}
