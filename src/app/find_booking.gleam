//// Application use case: load a booking with its items.

import domain/booking.{type Booking}
import domain/booking_item.{type BookingItem}
import domain/booking_repo.{type BookingRepo}
import domain/repo_error.{type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type FindBookingError {
  InvalidId
  NotFound
  RepoFailed(RepoError)
}

pub fn run(
  repo: BookingRepo,
  raw_id: String,
) -> Promise(Result(#(Booking, List(BookingItem)), FindBookingError)) {
  case booking.new_id(raw_id) {
    Error(_) -> promise.resolve(Error(InvalidId))
    Ok(bid) -> {
      use found <- promise.await(repo.find(bid))
      case found {
        Error(repo_error.NotFound) -> promise.resolve(Error(NotFound))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(bk) -> {
          use items <- promise.map(repo.list_items(bid))
          items
          |> result.map(fn(list) { #(bk, list) })
          |> result.map_error(RepoFailed)
        }
      }
    }
  }
}
