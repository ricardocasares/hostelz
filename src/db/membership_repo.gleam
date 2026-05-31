//// Postgres-backed adapter for the membership port. `count_owners` joins to
//// roles to count owner memberships (the last-owner guard).

import brioche/sql as db
import db/sql as queries
import domain/membership.{type Membership}
import domain/membership_repo.{type MembershipRepo, MembershipRepo}
import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError, Corrupt, NotFound, StorageError}
import domain/role
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> MembershipRepo {
  MembershipRepo(
    save: fn(m) { save(conn, m) },
    find: fn(org, uid) { find(conn, org, uid) },
    list_by_organization: fn(org) { list_by_organization(conn, org) },
    delete: fn(org, uid) { delete(conn, org, uid) },
    count_owners: fn(org) { count_owners(conn, org) },
  )
}

fn save(conn: db.Connection, m: Membership) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.insert_membership(
    conn,
    membership.membership_id(membership.id(m)),
    organization.organization_id(membership.organization_id(m)),
    user.user_id(membership.user_id(m)),
    role.role_id(membership.role_id(m)),
  ))
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn find(
  conn: db.Connection,
  org: OrganizationId,
  uid: UserId,
) -> Promise(Result(Membership, RepoError)) {
  use res <- promise.map(queries.find_membership(
    conn,
    organization.organization_id(org),
    user.user_id(uid),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(row.id, row.organization_id, row.user_id, row.role_id)
  }
}

fn list_by_organization(
  conn: db.Connection,
  org: OrganizationId,
) -> Promise(Result(List(Membership), RepoError)) {
  use res <- promise.map(queries.list_memberships_by_organization(
    conn,
    organization.organization_id(org),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) {
        reconstruct(row.id, row.organization_id, row.user_id, row.role_id)
      })
  }
}

fn delete(
  conn: db.Connection,
  org: OrganizationId,
  uid: UserId,
) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.delete_membership(
    conn,
    organization.organization_id(org),
    user.user_id(uid),
  ))
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn count_owners(
  conn: db.Connection,
  org: OrganizationId,
) -> Promise(Result(Int, RepoError)) {
  use res <- promise.map(queries.count_organization_owners(
    conn,
    organization.organization_id(org),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [row, ..], ..)) -> Ok(row.owners)
    Ok(db.Returned(rows: [], ..)) -> Ok(0)
  }
}

/// Rebuild a `Membership` from stored columns. Exposed for unit testing.
pub fn reconstruct(
  id: String,
  organization_id: String,
  user_id: String,
  role_id: String,
) -> Result(Membership, RepoError) {
  use mid <- result.try(membership.new_id(id) |> result.map_error(corrupt))
  use oid <- result.try(
    organization.new_id(organization_id) |> result.map_error(corrupt),
  )
  use uid <- result.try(user.new_id(user_id) |> result.map_error(corrupt))
  use rid <- result.try(role.new_id(role_id) |> result.map_error(corrupt))
  Ok(membership.new(mid, oid, uid, rid))
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
