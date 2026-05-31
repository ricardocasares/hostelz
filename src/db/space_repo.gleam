//// Postgres-backed adapter for the space persistence port. The tree is an
//// adjacency list: `parent_id` is nullable, so a root is written with the
//// `insert_space` upsert (parent left NULL) and a nested space with
//// `insert_space_with_parent` (squirrel can't express a nullable insert param —
//// same split as the guest inserts). Stored rows are rebuilt through the domain
//// smart constructors, so a row that no longer satisfies the rules surfaces as
//// `Corrupt`.

import brioche/sql as db
import db/sql as queries
import domain/organization.{type OrganizationId}
import domain/space.{type Space, type SpaceId}
import domain/space_repo.{
  type RepoError, type SpaceRepo, Corrupt, NotFound, SpaceRepo, StorageError,
}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub fn new(conn: db.Connection) -> SpaceRepo {
  SpaceRepo(
    save: fn(s) { save(conn, s) },
    find: fn(id) { find(conn, id) },
    list_by_organization: fn(org_id) { list_by_organization(conn, org_id) },
    list_children: fn(parent_id) { list_children(conn, parent_id) },
  )
}

fn save(conn: db.Connection, s: Space) -> Promise(Result(Nil, RepoError)) {
  let id = space.space_id(space.id(s))
  let org = organization.organization_id(space.organization_id(s))
  let is_grouping = space.kind_is_grouping(space.kind(s))
  let label = space.kind_label(space.kind(s))
  let name = space.name(s)
  let saved = case space.parent_id(s) {
    Some(pid) ->
      queries.insert_space_with_parent(
        conn,
        id,
        org,
        space.space_id(pid),
        is_grouping,
        label,
        name,
      )
    None -> queries.insert_space(conn, id, org, is_grouping, label, name)
  }
  use res <- promise.map(saved)
  res
  |> result.replace(Nil)
  |> result.map_error(storage_error)
}

fn find(conn: db.Connection, id: SpaceId) -> Promise(Result(Space, RepoError)) {
  use res <- promise.map(queries.find_space_by_id(conn, space.space_id(id)))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct(
        row.id,
        row.organization_id,
        row.parent_id,
        row.is_grouping,
        row.label,
        row.name,
      )
  }
}

fn list_by_organization(
  conn: db.Connection,
  org_id: OrganizationId,
) -> Promise(Result(List(Space), RepoError)) {
  use res <- promise.map(queries.list_spaces_by_organization(
    conn,
    organization.organization_id(org_id),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) {
        reconstruct(
          row.id,
          row.organization_id,
          row.parent_id,
          row.is_grouping,
          row.label,
          row.name,
        )
      })
  }
}

fn list_children(
  conn: db.Connection,
  parent_id: SpaceId,
) -> Promise(Result(List(Space), RepoError)) {
  use res <- promise.map(queries.list_spaces_by_parent(
    conn,
    space.space_id(parent_id),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) {
        reconstruct(
          row.id,
          row.organization_id,
          row.parent_id,
          row.is_grouping,
          row.label,
          row.name,
        )
      })
  }
}

/// Rebuild a `Space` from stored column values, re-running the domain smart
/// constructors. `parent_id` is nullable — `None` is a root. Exposed so the
/// reconstruction can be unit-tested without a database.
pub fn reconstruct(
  id: String,
  organization_id: String,
  parent_id: Option(String),
  is_grouping: Bool,
  label: String,
  name: String,
) -> Result(Space, RepoError) {
  use sid <- result.try(space.new_id(id) |> result.map_error(corrupt))
  use org_id <- result.try(
    organization.new_id(organization_id) |> result.map_error(corrupt),
  )
  use pid <- result.try(reconstruct_parent_id(parent_id))
  use kind <- result.try(reconstruct_kind(is_grouping, label))
  space.new(sid, org_id, pid, kind, name) |> result.map_error(corrupt)
}

fn reconstruct_parent_id(
  parent_id: Option(String),
) -> Result(Option(SpaceId), RepoError) {
  case parent_id {
    None -> Ok(None)
    Some(raw) ->
      space.new_id(raw) |> result.map(Some) |> result.map_error(corrupt)
  }
}

fn reconstruct_kind(
  is_grouping: Bool,
  label: String,
) -> Result(space.Kind, RepoError) {
  case is_grouping {
    True -> space.grouping(label)
    False -> space.unit(label)
  }
  |> result.map_error(corrupt)
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
