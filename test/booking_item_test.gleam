//// Unit tests for BookingItem: whole vs unit-in-room-type construction and the
//// assignment rules.

import domain/booking
import domain/booking_item
import domain/period
import domain/space
import gleam/option.{None, Some}

fn a_period() -> period.Period {
  let assert Ok(p) = period.new("2026-06-01", "2026-06-03")
  p
}

fn item_ids() -> #(booking_item.BookingItemId, booking.BookingId) {
  let assert Ok(iid) = booking_item.new_id("it_1")
  let assert Ok(bid) = booking.new_id("bk_1")
  #(iid, bid)
}

fn a_space(id: String) -> space.SpaceId {
  let assert Ok(sid) = space.new_id(id)
  sid
}

pub fn whole_is_pinned_and_assigned_test() {
  let #(iid, bid) = item_ids()
  let bed = a_space("bed_1")
  let item = booking_item.whole(iid, bid, a_period(), bed)
  assert booking_item.is_pinned(item)
  assert booking_item.assigned(item) == Some(bed)
  assert booking_item.target(item) == bed
  assert booking_item.kind_to_string(booking_item.kind(item)) == "whole"
}

pub fn unit_in_is_unassigned_test() {
  let #(iid, bid) = item_ids()
  let room_type = a_space("dorm_6")
  let item = booking_item.unit_in(iid, bid, a_period(), room_type)
  assert !booking_item.is_pinned(item)
  assert booking_item.assigned(item) == None
  assert booking_item.target(item) == room_type
  assert booking_item.kind_to_string(booking_item.kind(item)) == "unit_in_type"
}

pub fn assign_unassigned_succeeds_test() {
  let #(iid, bid) = item_ids()
  let item = booking_item.unit_in(iid, bid, a_period(), a_space("dorm_6"))
  let bed = a_space("bed_3")
  let assert Ok(updated) = booking_item.assign(item, bed)
  assert booking_item.assigned(updated) == Some(bed)
}

pub fn assign_already_assigned_rejected_test() {
  let #(iid, bid) = item_ids()
  let item = booking_item.whole(iid, bid, a_period(), a_space("bed_1"))
  assert booking_item.assign(item, a_space("bed_2"))
    == Error(booking_item.AlreadyAssigned)
}
