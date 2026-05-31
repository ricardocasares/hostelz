//// Postgres-backed adapter for the organization persistence port. Builds an
//// `organization_repo.OrganizationRepo` whose closures run the generated
//// squirrel queries (`db/sql`) against a brioche connection. Stored rows are
//// turned back into domain `Organization` values through the smart
//// constructors, so a row that no longer satisfies the domain rules surfaces as
//// `Corrupt`. Slug uniqueness is enforced by the database (`organizations_slug_key`)
//// and surfaced as `Conflict`.

import brioche/sql as db
import db/sql as queries
import domain/organization.{type Organization, type OrganizationId}
import domain/organization_repo.{
  type OrganizationRepo, type RepoError, Conflict, Corrupt, NotFound,
  OrganizationRepo, StorageError,
}
import domain/slug.{type Slug}
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> OrganizationRepo {
  OrganizationRepo(
    save: fn(o) { save(conn, o) },
    find: fn(id) { find(conn, id) },
    find_by_slug: fn(s) { find_by_slug(conn, s) },
    list_all: fn() { list_all(conn) },
    list_for_user: fn(uid) { list_for_user(conn, uid) },
  )
}

fn save(
  conn: db.Connection,
  o: Organization,
) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.insert_organization(
    conn,
    organization.organization_id(organization.id(o)),
    slug.to_string(organization.slug(o)),
    organization.name(o),
  ))
  res
  |> result.replace(Nil)
  |> result.map_error(save_error)
}

fn find(
  conn: db.Connection,
  id: OrganizationId,
) -> Promise(Result(Organization, RepoError)) {
  use res <- promise.map(queries.find_organization_by_id(
    conn,
    organization.organization_id(id),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(row.id, row.slug, row.name)
  }
}

fn find_by_slug(
  conn: db.Connection,
  s: Slug,
) -> Promise(Result(Organization, RepoError)) {
  use res <- promise.map(queries.find_organization_by_slug(
    conn,
    slug.to_string(s),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(row.id, row.slug, row.name)
  }
}

fn list_all(
  conn: db.Connection,
) -> Promise(Result(List(Organization), RepoError)) {
  use res <- promise.map(queries.list_organizations(conn))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) { reconstruct(row.id, row.slug, row.name) })
  }
}

fn list_for_user(
  conn: db.Connection,
  uid: UserId,
) -> Promise(Result(List(Organization), RepoError)) {
  use res <- promise.map(queries.list_user_organizations(conn, user.user_id(uid)))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) { reconstruct(row.id, row.slug, row.name) })
  }
}

/// Rebuild an `Organization` from stored column values, re-running the domain
/// smart constructors. Exposed so reconstruction can be unit-tested without a
/// database.
pub fn reconstruct(
  id: String,
  raw_slug: String,
  name: String,
) -> Result(Organization, RepoError) {
  use oid <- result.try(organization.new_id(id) |> result.map_error(corrupt))
  use org_slug <- result.try(slug.new(raw_slug) |> result.map_error(corrupt))
  organization.new(oid, org_slug, name) |> result.map_error(corrupt)
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

/// A unique-constraint violation on the slug index is a `Conflict`; anything
/// else is an opaque storage failure.
fn save_error(error: db.SqlError) -> RepoError {
  case error {
    db.ConstraintViolated(constraint: "organizations_slug_key", ..) ->
      Conflict("slug already taken")
    _ -> storage_error(error)
  }
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
