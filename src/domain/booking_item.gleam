//// A line item within a Booking: one space-claim for a period. Either pinned to
//// a specific space (`WholeSpace` — a bed, or a room/floor booked whole, always
//// assigned) or an unassigned hold against a one-level room-type
//// (`UnitInRoomType` — the physical bed is chosen at check-in via `assign`).

import domain/booking.{type BookingId}
import domain/period.{type Period}
import domain/space.{type SpaceId}
import gleam/option.{type Option, None, Some}
import gleam/string

pub opaque type BookingItemId {
  BookingItemId(value: String)
}

pub type ItemKind {
  WholeSpace(space: SpaceId)
  UnitInRoomType(room_type: SpaceId)
}

pub opaque type BookingItem {
  BookingItem(
    id: BookingItemId,
    booking_id: BookingId,
    period: Period,
    kind: ItemKind,
    assigned: Option(SpaceId),
  )
}

pub type BookingItemError {
  EmptyId
}

pub type AssignError {
  AlreadyAssigned
  NotDeferred
}

pub fn new_id(raw: String) -> Result(BookingItemId, BookingItemError) {
  case string.trim(raw) {
    "" -> Error(EmptyId)
    trimmed -> Ok(BookingItemId(trimmed))
  }
}

/// A whole-space item: pins `space` (a bed, or a grouping booked as a whole).
pub fn whole(
  id: BookingItemId,
  booking_id: BookingId,
  period: Period,
  space: SpaceId,
) -> BookingItem {
  BookingItem(id, booking_id, period, WholeSpace(space), Some(space))
}

/// An unassigned hold: a bed within `room_type`, physical bed chosen later.
pub fn unit_in(
  id: BookingItemId,
  booking_id: BookingId,
  period: Period,
  room_type: SpaceId,
) -> BookingItem {
  BookingItem(id, booking_id, period, UnitInRoomType(room_type), None)
}

/// Rebuild an item from stored parts (used by the adapter on load).
pub fn restore(
  id: BookingItemId,
  booking_id: BookingId,
  period: Period,
  kind: ItemKind,
  assigned: Option(SpaceId),
) -> BookingItem {
  BookingItem(id, booking_id, period, kind, assigned)
}

/// Assign a free physical bed to an unassigned hold (at check-in).
pub fn assign(
  item: BookingItem,
  space: SpaceId,
) -> Result(BookingItem, AssignError) {
  case item.kind, item.assigned {
    _, Some(_) -> Error(AlreadyAssigned)
    UnitInRoomType(_), None -> Ok(BookingItem(..item, assigned: Some(space)))
    WholeSpace(_), None -> Error(NotDeferred)
  }
}

// accessors
pub fn id(item: BookingItem) -> BookingItemId {
  item.id
}

pub fn booking_item_id(id: BookingItemId) -> String {
  id.value
}

pub fn booking_id(item: BookingItem) -> BookingId {
  item.booking_id
}

pub fn period(item: BookingItem) -> Period {
  item.period
}

pub fn kind(item: BookingItem) -> ItemKind {
  item.kind
}

pub fn assigned(item: BookingItem) -> Option(SpaceId) {
  item.assigned
}

pub fn is_pinned(item: BookingItem) -> Bool {
  case item.kind {
    WholeSpace(_) -> True
    UnitInRoomType(_) -> False
  }
}

/// The space an item targets: the pinned node for `WholeSpace`, the room-type
/// for `UnitInRoomType`.
pub fn target(item: BookingItem) -> SpaceId {
  case item.kind {
    WholeSpace(space) -> space
    UnitInRoomType(room_type) -> room_type
  }
}

pub fn kind_to_string(kind: ItemKind) -> String {
  case kind {
    WholeSpace(_) -> "whole"
    UnitInRoomType(_) -> "unit_in_type"
  }
}
