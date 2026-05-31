//// Unit tests for the Period value object: ISO parsing, calendar validity, and
//// the positive-nights rule.

import domain/period
import gleam/time/calendar

pub fn valid_period_round_trips_test() {
  let assert Ok(p) = period.new("2026-06-01", "2026-06-03")
  assert period.check_in_iso(p) == "2026-06-01"
  assert period.check_out_iso(p) == "2026-06-03"
}

pub fn check_in_accessor_is_a_date_test() {
  let assert Ok(p) = period.new("2026-06-01", "2026-06-03")
  assert period.check_in(p) == calendar.Date(2026, calendar.June, 1)
}

pub fn zero_nights_rejected_test() {
  assert period.new("2026-06-01", "2026-06-01")
    == Error(period.NotPositiveNights)
}

pub fn checkout_before_checkin_rejected_test() {
  assert period.new("2026-06-03", "2026-06-01")
    == Error(period.NotPositiveNights)
}

pub fn invalid_calendar_date_rejected_test() {
  assert period.new("2026-02-30", "2026-03-05") == Error(period.InvalidCheckIn)
}

pub fn malformed_check_in_rejected_test() {
  assert period.new("nope", "2026-03-01") == Error(period.InvalidCheckIn)
}

pub fn malformed_check_out_rejected_test() {
  assert period.new("2026-06-01", "later") == Error(period.InvalidCheckOut)
}
