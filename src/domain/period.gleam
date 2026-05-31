//// A booking period: nights as a half-open range [check_in, check_out). Dates
//// are `calendar.Date` values; the smart constructor parses ISO `YYYY-MM-DD`
//// strings at the boundary, rejects invalid calendar dates, and requires at
//// least one night (check_out strictly after check_in).

import gleam/int
import gleam/order.{type Order}
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date, Date}

pub opaque type Period {
  Period(check_in: Date, check_out: Date)
}

pub type PeriodError {
  InvalidCheckIn
  InvalidCheckOut
  NotPositiveNights
}

/// Build a period from two ISO `YYYY-MM-DD` strings.
pub fn new(check_in: String, check_out: String) -> Result(Period, PeriodError) {
  use ci <- result.try(parse(check_in) |> result.replace_error(InvalidCheckIn))
  use co <- result.try(
    parse(check_out) |> result.replace_error(InvalidCheckOut),
  )
  case compare(ci, co) {
    order.Lt -> Ok(Period(ci, co))
    _ -> Error(NotPositiveNights)
  }
}

pub fn check_in(period: Period) -> Date {
  period.check_in
}

pub fn check_out(period: Period) -> Date {
  period.check_out
}

pub fn check_in_iso(period: Period) -> String {
  to_iso(period.check_in)
}

pub fn check_out_iso(period: Period) -> String {
  to_iso(period.check_out)
}

fn parse(raw: String) -> Result(Date, Nil) {
  case string.split(string.trim(raw), "-") {
    [y, m, d] -> {
      use year <- result.try(int.parse(y))
      use month_num <- result.try(int.parse(m))
      use day <- result.try(int.parse(d))
      use month <- result.try(calendar.month_from_int(month_num))
      let date = Date(year, month, day)
      case calendar.is_valid_date(date) {
        True -> Ok(date)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn to_iso(date: Date) -> String {
  let Date(year, month, day) = date
  pad(year, 4)
  <> "-"
  <> pad(calendar.month_to_int(month), 2)
  <> "-"
  <> pad(day, 2)
}

fn pad(value: Int, width: Int) -> String {
  int.to_string(value) |> string.pad_start(width, "0")
}

fn compare(a: Date, b: Date) -> Order {
  let Date(ay, am, ad) = a
  let Date(by, bm, bd) = b
  case int.compare(ay, by) {
    order.Eq ->
      case int.compare(calendar.month_to_int(am), calendar.month_to_int(bm)) {
        order.Eq -> int.compare(ad, bd)
        other -> other
      }
    other -> other
  }
}
