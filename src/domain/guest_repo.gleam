//// The persistence *port* for guests: a record of functions the application
//// depends on, with no knowledge of how guests are stored. Adapters — such as
//// `db/guest_repo`, backed by Postgres — build a value of this type, so the
//// domain and use cases never import a database library.

import domain/guest.{type Guest, type GuestId}
import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import gleam/javascript/promise.{type Promise}

/// The guest repository, as a record of functions. Build one with an adapter
/// such as `db/guest_repo.new`. Every operation is async (`Promise`) because the
/// only adapter so far talks to Postgres over Bun's SQL client.
pub type GuestRepo {
  GuestRepo(
    save: fn(Guest) -> Promise(Result(Nil, RepoError)),
    find: fn(GuestId) -> Promise(Result(Guest, RepoError)),
    list_by_organization: fn(OrganizationId) ->
      Promise(Result(List(Guest), RepoError)),
  )
}
