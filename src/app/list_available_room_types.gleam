//// Application use case: list a room-type's availability (beds left) over a
//// period — capacity-count based, the channel-friendly view of inventory.
//// Only room-types with at least one bed free are returned.

import domain/booking_repo.{type BookingRepo, type RoomType}
import domain/organization.{type OrganizationId}
import domain/period.{type Period}
import domain/repo_error.{type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/list

pub type AvailableRoomType {
  AvailableRoomType(room_type: RoomType, beds_left: Int)
}

pub type ListAvailableError {
  InvalidPeriod(period.PeriodError)
  RepoFailed(RepoError)
}

pub fn run(
  repo: BookingRepo,
  organization_id: OrganizationId,
  check_in: String,
  check_out: String,
) -> Promise(Result(List(AvailableRoomType), ListAvailableError)) {
  case period.new(check_in, check_out) {
    Error(e) -> promise.resolve(Error(InvalidPeriod(e)))
    Ok(p) -> {
      use rts <- promise.await(repo.list_room_types(organization_id))
      case rts {
        Error(e) -> promise.resolve(Error(RepoFailed(e)))
        Ok(room_types) -> compute(repo, p, room_types, [])
      }
    }
  }
}

fn compute(
  repo: BookingRepo,
  p: Period,
  room_types: List(RoomType),
  acc: List(AvailableRoomType),
) -> Promise(Result(List(AvailableRoomType), ListAvailableError)) {
  case room_types {
    [] -> promise.resolve(Ok(list.reverse(acc)))
    [rt, ..rest] -> {
      use left <- promise.await(repo.beds_left(rt.id, p))
      case left {
        Error(e) -> promise.resolve(Error(RepoFailed(e)))
        Ok(n) -> {
          let acc = case n > 0 {
            True -> [AvailableRoomType(rt, n), ..acc]
            False -> acc
          }
          compute(repo, p, rest, acc)
        }
      }
    }
  }
}
