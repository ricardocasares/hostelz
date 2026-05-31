//// Application use case: move a booking through its lifecycle. The domain
//// decides whether a transition is legal; the adapter frees the booking's
//// inventory when the new status is non-blocking.

import domain/booking.{type Booking}
import domain/booking_repo.{type BookingRepo}
import domain/repo_error.{type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type Transition {
  Confirm
  CheckIn
  CheckOut
  Cancel
  NoShow
}

pub type TransitionBookingError {
  InvalidId
  NotFound
  InvalidTransition
  RepoFailed(RepoError)
}

pub fn run(
  repo: BookingRepo,
  raw_id: String,
  transition: Transition,
) -> Promise(Result(Booking, TransitionBookingError)) {
  case booking.new_id(raw_id) {
    Error(_) -> promise.resolve(Error(InvalidId))
    Ok(bid) -> {
      use found <- promise.await(repo.find(bid))
      case found {
        Error(repo_error.NotFound) -> promise.resolve(Error(NotFound))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(bk) ->
          case apply(bk, transition) {
            Error(_) -> promise.resolve(Error(InvalidTransition))
            Ok(updated) -> {
              let frees = !booking.is_blocking(booking.status(updated))
              use saved <- promise.map(repo.apply_transition(updated, frees))
              saved |> result.replace(updated) |> result.map_error(RepoFailed)
            }
          }
      }
    }
  }
}

fn apply(
  bk: Booking,
  transition: Transition,
) -> Result(Booking, booking.TransitionError) {
  case transition {
    Confirm -> booking.confirm(bk)
    CheckIn -> booking.check_in(bk)
    CheckOut -> booking.check_out(bk)
    Cancel -> booking.cancel(bk)
    NoShow -> booking.no_show(bk)
  }
}
