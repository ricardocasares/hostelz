//// Persistence port for sessions. Only the hash of a token is stored; the
//// raw token never touches the database. `find_user` returns the owning user
//// only for an *unexpired* session (expiry is filtered in SQL).

import domain/repo_error.{type RepoError}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}

pub type SessionRepo {
  SessionRepo(
    save: fn(String, UserId) -> Promise(Result(Nil, RepoError)),
    find_user: fn(String) -> Promise(Result(UserId, RepoError)),
    delete: fn(String) -> Promise(Result(Nil, RepoError)),
  )
}
