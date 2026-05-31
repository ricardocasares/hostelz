//// Application use case: how many bookable beds are left in a room-type over a
//// period.

import domain/booking_repo.{type BookingRepo}
import domain/period
import domain/repo_error.{type RepoError}
import domain/space
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type CheckAvailabilityError {
  InvalidId
  InvalidPeriod(period.PeriodError)
  RepoFailed(RepoError)
}

pub fn run(
  repo: BookingRepo,
  raw_room_type: String,
  check_in: String,
  check_out: String,
) -> Promise(Result(Int, CheckAvailabilityError)) {
  case space.new_id(raw_room_type), period.new(check_in, check_out) {
    Error(_), _ -> promise.resolve(Error(InvalidId))
    _, Error(e) -> promise.resolve(Error(InvalidPeriod(e)))
    Ok(room_type), Ok(p) -> {
      use res <- promise.map(repo.beds_left(room_type, p))
      result.map_error(res, RepoFailed)
    }
  }
}
