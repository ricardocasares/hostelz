//// Persistence port for a user's password hash (kept separate from the `User`
//// identity aggregate). The hash is an opaque string produced by `auth/password`.

import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}

pub type RepoError {
  NotFound
  StorageError(String)
}

pub type CredentialRepo {
  CredentialRepo(
    save: fn(UserId, String) -> Promise(Result(Nil, RepoError)),
    find_hash: fn(UserId) -> Promise(Result(String, RepoError)),
  )
}
