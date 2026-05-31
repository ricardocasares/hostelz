//// Application use case: reparent a space. Refused while the space's subtree
//// carries active booking demand (moving it would strand the materialized
//// occupancy). The new parent must exist, be a grouping in the same
//// organization, and not be the space itself or one of its descendants (which
//// would create a cycle).

import domain/booking_repo.{type BookingRepo}
import domain/repo_error.{type RepoError}
import domain/space.{type Space, type SpaceId}
import domain/space_repo.{type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import gleam/result

pub type MoveSpaceError {
  InvalidId(space.SpaceError)
  NotFound
  HasActiveReservations
  ParentNotFound
  ParentNotGrouping
  ParentDifferentOrganization
  WouldCreateCycle
  RepoFailed(RepoError)
}

pub fn run(
  space_repo: SpaceRepo,
  booking_repo: BookingRepo,
  raw_id: String,
  new_parent: Option(String),
) -> Promise(Result(Space, MoveSpaceError)) {
  case space.new_id(raw_id) {
    Error(e) -> promise.resolve(Error(InvalidId(e)))
    Ok(sid) -> {
      use found <- promise.await(space_repo.find(sid))
      case found {
        Error(repo_error.NotFound) -> promise.resolve(Error(NotFound))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(sp) -> {
          use active <- promise.await(booking_repo.space_has_active_demand(sid))
          case active {
            Error(e) -> promise.resolve(Error(RepoFailed(e)))
            Ok(True) -> promise.resolve(Error(HasActiveReservations))
            Ok(False) -> validate(space_repo, sp, sid, new_parent)
          }
        }
      }
    }
  }
}

fn validate(
  space_repo: SpaceRepo,
  sp: Space,
  sid: SpaceId,
  new_parent: Option(String),
) -> Promise(Result(Space, MoveSpaceError)) {
  case new_parent {
    None -> persist(space_repo, sp, None)
    Some(raw) ->
      case space.new_id(raw) {
        Error(e) -> promise.resolve(Error(InvalidId(e)))
        Ok(pid) -> {
          use parent <- promise.await(space_repo.find(pid))
          case parent {
            Error(repo_error.NotFound) -> promise.resolve(Error(ParentNotFound))
            Error(other) -> promise.resolve(Error(RepoFailed(other)))
            Ok(parent_space) ->
              case
                space.organization_id(parent_space) == space.organization_id(sp),
                space.can_contain(parent_space)
              {
                False, _ -> promise.resolve(Error(ParentDifferentOrganization))
                _, False -> promise.resolve(Error(ParentNotGrouping))
                True, True -> guard_cycle(space_repo, sp, sid, pid)
              }
          }
        }
      }
  }
}

fn guard_cycle(
  space_repo: SpaceRepo,
  sp: Space,
  sid: SpaceId,
  pid: SpaceId,
) -> Promise(Result(Space, MoveSpaceError)) {
  use cyclic <- promise.await(would_cycle(space_repo, sid, pid))
  case cyclic {
    Error(e) -> promise.resolve(Error(RepoFailed(e)))
    Ok(True) -> promise.resolve(Error(WouldCreateCycle))
    Ok(False) -> persist(space_repo, sp, Some(pid))
  }
}

/// Walk up from `candidate`; a cycle would form if `sid` is an ancestor-or-self.
fn would_cycle(
  space_repo: SpaceRepo,
  sid: SpaceId,
  candidate: SpaceId,
) -> Promise(Result(Bool, RepoError)) {
  case candidate == sid {
    True -> promise.resolve(Ok(True))
    False -> {
      use found <- promise.await(space_repo.find(candidate))
      case found {
        Error(repo_error.NotFound) -> promise.resolve(Ok(False))
        Error(other) -> promise.resolve(Error(other))
        Ok(node) ->
          case space.parent_id(node) {
            None -> promise.resolve(Ok(False))
            Some(parent) -> would_cycle(space_repo, sid, parent)
          }
      }
    }
  }
}

fn persist(
  space_repo: SpaceRepo,
  sp: Space,
  new_parent: Option(SpaceId),
) -> Promise(Result(Space, MoveSpaceError)) {
  let moved = space.reparent(sp, new_parent)
  use saved <- promise.map(space_repo.save(moved))
  saved |> result.replace(moved) |> result.map_error(RepoFailed)
}
