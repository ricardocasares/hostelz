//// The Booking aggregate root. A booking groups one or more `BookingItem`s
//// (each a space-claim for a period) for an optional guest (none = a
//// maintenance/blocking hold). The status is the booking-level lifecycle;
//// blocking statuses hold inventory, terminal ones free it. Transitions are the
//// only way to change status and are named, exhaustive, and reject illegal
//// moves.

import domain/guest.{type GuestId}
import domain/organization.{type OrganizationId}
import gleam/option.{type Option}
import gleam/string

pub opaque type BookingId {
  BookingId(value: String)
}

pub type Status {
  Pending
  Confirmed
  CheckedIn
  CheckedOut
  Cancelled
  NoShow
}

pub opaque type Booking {
  Booking(
    id: BookingId,
    organization_id: OrganizationId,
    guest_id: Option(GuestId),
    status: Status,
  )
}

pub type BookingError {
  EmptyId
}

pub type TransitionError {
  InvalidTransition(from: Status, to: Status)
}

pub fn new_id(raw: String) -> Result(BookingId, BookingError) {
  case string.trim(raw) {
    "" -> Error(EmptyId)
    trimmed -> Ok(BookingId(trimmed))
  }
}

pub fn new(
  id: BookingId,
  organization_id: OrganizationId,
  guest_id: Option(GuestId),
  status: Status,
) -> Booking {
  Booking(id, organization_id, guest_id, status)
}

// accessors
pub fn id(booking: Booking) -> BookingId {
  booking.id
}

pub fn booking_id(id: BookingId) -> String {
  id.value
}

pub fn organization_id(booking: Booking) -> OrganizationId {
  booking.organization_id
}

pub fn guest_id(booking: Booking) -> Option(GuestId) {
  booking.guest_id
}

pub fn status(booking: Booking) -> Status {
  booking.status
}

/// A blocking status holds inventory (demand rows exist); a terminal status
/// frees it.
pub fn is_blocking(status: Status) -> Bool {
  case status {
    Pending | Confirmed | CheckedIn -> True
    CheckedOut | Cancelled | NoShow -> False
  }
}

// transitions — named and exhaustive, rejecting illegal moves
pub fn confirm(booking: Booking) -> Result(Booking, TransitionError) {
  case booking.status {
    Pending -> Ok(Booking(..booking, status: Confirmed))
    other -> Error(InvalidTransition(other, Confirmed))
  }
}

pub fn check_in(booking: Booking) -> Result(Booking, TransitionError) {
  case booking.status {
    Confirmed -> Ok(Booking(..booking, status: CheckedIn))
    other -> Error(InvalidTransition(other, CheckedIn))
  }
}

pub fn check_out(booking: Booking) -> Result(Booking, TransitionError) {
  case booking.status {
    CheckedIn -> Ok(Booking(..booking, status: CheckedOut))
    other -> Error(InvalidTransition(other, CheckedOut))
  }
}

pub fn cancel(booking: Booking) -> Result(Booking, TransitionError) {
  case booking.status {
    Pending | Confirmed -> Ok(Booking(..booking, status: Cancelled))
    other -> Error(InvalidTransition(other, Cancelled))
  }
}

pub fn no_show(booking: Booking) -> Result(Booking, TransitionError) {
  case booking.status {
    Pending | Confirmed -> Ok(Booking(..booking, status: NoShow))
    other -> Error(InvalidTransition(other, NoShow))
  }
}

pub fn status_to_string(status: Status) -> String {
  case status {
    Pending -> "pending"
    Confirmed -> "confirmed"
    CheckedIn -> "checked_in"
    CheckedOut -> "checked_out"
    Cancelled -> "cancelled"
    NoShow -> "no_show"
  }
}

pub fn status_from_string(raw: String) -> Result(Status, Nil) {
  case raw {
    "pending" -> Ok(Pending)
    "confirmed" -> Ok(Confirmed)
    "checked_in" -> Ok(CheckedIn)
    "checked_out" -> Ok(CheckedOut)
    "cancelled" -> Ok(Cancelled)
    "no_show" -> Ok(NoShow)
    _ -> Error(Nil)
  }
}
