//// The persistence *port* for users (system accounts): a record of functions
//// the application depends on, with no knowledge of how users are stored.
//// Adapters — such as `db/user_repo`, backed by Postgres — build a value of
//// this type.

import domain/email.{type Email}
import domain/repo_error.{type RepoError}
import domain/user.{type User, type UserId}
import gleam/javascript/promise.{type Promise}

pub type UserRepo {
  UserRepo(
    save: fn(User) -> Promise(Result(Nil, RepoError)),
    find: fn(UserId) -> Promise(Result(User, RepoError)),
    find_by_email: fn(Email) -> Promise(Result(User, RepoError)),
    list_all: fn() -> Promise(Result(List(User), RepoError)),
  )
}
