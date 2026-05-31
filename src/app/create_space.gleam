//// Application use case: create a space (a bookable unit or grouping).
////
//// Validates the kind + name through the domain, then — if the space is nested
//// under a parent — loads the parent to enforce the rules a child can't check
//// from its own record: the parent must exist, must be a grouping (a `Unit` is
//// a leaf and cannot contain children), and must belong to the same
//// organization. Finally persists via the repository port.

import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import domain/space.{type Space, type SpaceId}
import domain/space_repo.{type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/result

pub type CreateSpaceError {
  InvalidSpace(space.SpaceError)
  ParentNotFound
  ParentNotGrouping
  ParentDifferentOrganization
  RepoFailed(RepoError)
}

pub fn run(
  repo: SpaceRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  parent_id: Option(SpaceId),
  is_grouping: Bool,
  label: String,
  name: String,
) -> Promise(Result(Space, CreateSpaceError)) {
  case
    build(generate_id(), organization_id, parent_id, is_grouping, label, name)
  {
    Error(error) -> promise.resolve(Error(error))
    Ok(new_space) -> {
      use checked <- promise.await(check_parent(
        repo,
        organization_id,
        parent_id,
      ))
      case checked {
        Error(error) -> promise.resolve(Error(error))
        Ok(Nil) -> {
          use saved <- promise.map(repo.save(new_space))
          saved
          |> result.replace(new_space)
          |> result.map_error(RepoFailed)
        }
      }
    }
  }
}

/// Pure validation: turn raw inputs into a valid `Space` or a wrapped domain
/// error. No IO — the parent rules (which need the parent row) live in `run`.
fn build(
  id: String,
  organization_id: OrganizationId,
  parent_id: Option(SpaceId),
  is_grouping: Bool,
  label: String,
  name: String,
) -> Result(Space, CreateSpaceError) {
  use kind <- result.try(build_kind(is_grouping, label))
  use sid <- result.try(space.new_id(id) |> result.map_error(InvalidSpace))
  space.new(sid, organization_id, parent_id, kind, name)
  |> result.map_error(InvalidSpace)
}

fn build_kind(
  is_grouping: Bool,
  label: String,
) -> Result(space.Kind, CreateSpaceError) {
  case is_grouping {
    True -> space.grouping(label)
    False -> space.unit(label)
  }
  |> result.map_error(InvalidSpace)
}

fn check_parent(
  repo: SpaceRepo,
  organization_id: OrganizationId,
  parent_id: Option(SpaceId),
) -> Promise(Result(Nil, CreateSpaceError)) {
  case parent_id {
    None -> promise.resolve(Ok(Nil))
    Some(pid) -> {
      use found <- promise.map(repo.find(pid))
      case found {
        Error(repo_error.NotFound) -> Error(ParentNotFound)
        Error(other) -> Error(RepoFailed(other))
        Ok(parent) -> validate_parent(parent, organization_id)
      }
    }
  }
}

fn validate_parent(
  parent: Space,
  organization_id: OrganizationId,
) -> Result(Nil, CreateSpaceError) {
  case space.organization_id(parent) == organization_id {
    False -> Error(ParentDifferentOrganization)
    True ->
      case space.can_contain(parent) {
        False -> Error(ParentNotGrouping)
        True -> Ok(Nil)
      }
  }
}
