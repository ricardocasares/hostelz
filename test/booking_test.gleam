//// Unit tests for the Booking aggregate: the status transition matrix,
//// is_blocking, and status string round-tripping.

import domain/booking.{
  Cancelled, CheckedIn, CheckedOut, Confirmed, NoShow, Pending,
}
import domain/organization
import gleam/list
import gleam/option.{None}

fn a_booking(status: booking.Status) -> booking.Booking {
  let assert Ok(bid) = booking.new_id("bk_1")
  let assert Ok(oid) = organization.new_id("org_1")
  booking.new(bid, oid, None, status)
}

pub fn pending_confirms_test() {
  let assert Ok(b) = booking.confirm(a_booking(Pending))
  assert booking.status(b) == Confirmed
}

pub fn confirmed_cannot_confirm_again_test() {
  assert booking.confirm(a_booking(Confirmed))
    == Error(booking.InvalidTransition(Confirmed, Confirmed))
}

pub fn confirmed_checks_in_test() {
  let assert Ok(b) = booking.check_in(a_booking(Confirmed))
  assert booking.status(b) == CheckedIn
}

pub fn checked_in_checks_out_test() {
  let assert Ok(b) = booking.check_out(a_booking(CheckedIn))
  assert booking.status(b) == CheckedOut
}

pub fn pending_cancels_test() {
  let assert Ok(b) = booking.cancel(a_booking(Pending))
  assert booking.status(b) == Cancelled
}

pub fn confirmed_no_shows_test() {
  let assert Ok(b) = booking.no_show(a_booking(Confirmed))
  assert booking.status(b) == NoShow
}

pub fn check_out_requires_checked_in_test() {
  assert booking.check_out(a_booking(Pending))
    == Error(booking.InvalidTransition(Pending, CheckedOut))
}

pub fn terminal_states_reject_transitions_test() {
  assert booking.cancel(a_booking(CheckedOut))
    == Error(booking.InvalidTransition(CheckedOut, Cancelled))
  assert booking.confirm(a_booking(Cancelled))
    == Error(booking.InvalidTransition(Cancelled, Confirmed))
}

pub fn blocking_states_test() {
  assert booking.is_blocking(Pending)
  assert booking.is_blocking(Confirmed)
  assert booking.is_blocking(CheckedIn)
  assert !booking.is_blocking(CheckedOut)
  assert !booking.is_blocking(Cancelled)
  assert !booking.is_blocking(NoShow)
}

pub fn status_round_trips_test() {
  [Pending, Confirmed, CheckedIn, CheckedOut, Cancelled, NoShow]
  |> list.each(fn(status) {
    assert booking.status_from_string(booking.status_to_string(status))
      == Ok(status)
  })
}
