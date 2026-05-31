//// Postgres-backed adapter for the role port. A role is stored as a row plus a
//// set of `role_permissions`; `save` upserts the row then replaces the
//// permission set (clear + re-insert). `find`/`list` load the row(s) and their
//// permissions, rebuilding through the domain smart constructors.

import brioche/sql as db
import db/sql as queries
import domain/organization.{type OrganizationId}
import domain/permission.{type Permission}
import domain/role.{type Role, type RoleId}
import domain/role_repo.{
  type RepoError, type RoleRepo, Conflict, Corrupt, NotFound, RoleRepo,
  StorageError,
}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> RoleRepo {
  RoleRepo(
    save: fn(r) { save(conn, r) },
    find: fn(id) { find(conn, id) },
    list_by_organization: fn(org) { list_by_organization(conn, org) },
    delete: fn(id) { delete(conn, id) },
  )
}

fn save(conn: db.Connection, r: Role) -> Promise(Result(Nil, RepoError)) {
  use row_saved <- promise.await(queries.insert_role(
    conn,
    role.role_id(role.id(r)),
    organization.organization_id(role.organization_id(r)),
    role.name(r),
    role.is_owner(r),
  ))
  case row_saved {
    Error(e) -> promise.resolve(Error(save_error(e)))
    Ok(_) -> replace_permissions(conn, r)
  }
}

fn replace_permissions(
  conn: db.Connection,
  r: Role,
) -> Promise(Result(Nil, RepoError)) {
  let role_id = role.role_id(role.id(r))
  use cleared <- promise.await(queries.delete_role_permissions(conn, role_id))
  case cleared {
    Error(e) -> promise.resolve(Error(storage_error(e)))
    Ok(_) -> {
      let inserts =
        list.map(role.permissions(r), fn(p) {
          queries.insert_role_permission(conn, role_id, permission.to_string(p))
        })
      use results <- promise.map(promise.await_list(inserts))
      results
      |> result.all
      |> result.replace(Nil)
      |> result.map_error(storage_error)
    }
  }
}

fn find(conn: db.Connection, id: RoleId) -> Promise(Result(Role, RepoError)) {
  use res <- promise.await(queries.find_role_by_id(conn, role.role_id(id)))
  case res {
    Error(e) -> promise.resolve(Error(storage_error(e)))
    Ok(db.Returned(rows: [], ..)) -> promise.resolve(Error(NotFound))
    Ok(db.Returned(rows: [row, ..], ..)) ->
      with_permissions(conn, row.id, row.organization_id, row.name, row.is_owner)
  }
}

fn list_by_organization(
  conn: db.Connection,
  org: OrganizationId,
) -> Promise(Result(List(Role), RepoError)) {
  use res <- promise.await(queries.list_roles_by_organization(
    conn,
    organization.organization_id(org),
  ))
  case res {
    Error(e) -> promise.resolve(Error(storage_error(e)))
    Ok(db.Returned(rows:, ..)) -> {
      let loads =
        list.map(rows, fn(row) {
          with_permissions(conn, row.id, row.organization_id, row.name, row.is_owner)
        })
      use results <- promise.map(promise.await_list(loads))
      result.all(results)
    }
  }
}

/// Load a role's permissions and rebuild the `Role`.
fn with_permissions(
  conn: db.Connection,
  id: String,
  organization_id: String,
  name: String,
  is_owner: Bool,
) -> Promise(Result(Role, RepoError)) {
  use res <- promise.map(queries.list_role_permissions(conn, id))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      reconstruct(
        id,
        organization_id,
        name,
        is_owner,
        list.map(rows, fn(row) { row.permission }),
      )
  }
}

/// Rebuild a `Role` from stored columns. Exposed for unit testing.
pub fn reconstruct(
  id: String,
  organization_id: String,
  name: String,
  is_owner: Bool,
  permission_strings: List(String),
) -> Result(Role, RepoError) {
  use rid <- result.try(role.new_id(id) |> result.map_error(corrupt))
  use oid <- result.try(
    organization.new_id(organization_id) |> result.map_error(corrupt),
  )
  use permissions <- result.try(parse_permissions(permission_strings))
  role.restore(rid, oid, name, is_owner, permissions)
  |> result.map_error(corrupt)
}

fn parse_permissions(
  raw: List(String),
) -> Result(List(Permission), RepoError) {
  list.try_map(raw, fn(s) {
    permission.from_string(s)
    |> result.replace_error(Corrupt("unknown permission: " <> s))
  })
}

fn delete(conn: db.Connection, id: RoleId) -> Promise(Result(Nil, RepoError)) {
  use res <- promise.map(queries.delete_role(conn, role.role_id(id)))
  res
  |> result.replace(Nil)
  |> result.map_error(delete_error)
}

/// A unique role name per org is a `Conflict`.
fn save_error(error: db.SqlError) -> RepoError {
  case error {
    db.ConstraintViolated(constraint: "roles_org_name_key", ..) ->
      Conflict("role name already used")
    _ -> storage_error(error)
  }
}

/// A role still assigned to a member can't be deleted (membership FK).
fn delete_error(error: db.SqlError) -> RepoError {
  case error {
    db.ConstraintViolated(..) -> Conflict("role is still assigned to a member")
    _ -> storage_error(error)
  }
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
