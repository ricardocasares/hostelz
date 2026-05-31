//// Integration tests against Postgres, through the booking use cases and the
//// adapter. Fixture: Hostel(bookable) > Dorm(room-type) > B1, B2 (capacity 2),
//// proving capacity counting, pinned exclusivity, whole-node booking, nesting,
//// assignment at check-in, and freeing on cancel. Requires the test DB.

import app/assign_booking_item
import app/create_booking.{type NewItem, NewItem}
import app/transition_booking
import db/booking_repo
import db/guest_repo
import db/organization_repo
import db/space_repo
import domain/booking
import domain/booking_item
import domain/organization.{type OrganizationId}
import domain/period
import domain/slug
import domain/space
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}
import router/context
import support

const d1 = "2026-06-01"

const d2 = "2026-06-02"

const d3 = "2026-06-03"

const d4 = "2026-06-04"

fn book(
  deps: context.Deps,
  oid: OrganizationId,
  items: List(NewItem),
) -> Promise(Result(booking.Booking, create_booking.CreateBookingError)) {
  create_booking.run(
    space_repo.new(deps.db),
    booking_repo.new(deps.db),
    guest_repo.new(deps.db),
    deps.generate_id,
    oid,
    None,
    items,
  )
}

fn unit_item(room_type: String, ci: String, co: String) -> NewItem {
  NewItem(kind: "unit", space_id: room_type, check_in: ci, check_out: co)
}

fn whole_item(sp: String, ci: String, co: String) -> NewItem {
  NewItem(kind: "whole", space_id: sp, check_in: ci, check_out: co)
}

fn a_period(ci: String, co: String) -> period.Period {
  let assert Ok(p) = period.new(ci, co)
  p
}

fn a_space(id: String) -> space.SpaceId {
  let assert Ok(sid) = space.new_id(id)
  sid
}

/// Truncate, seed an org, and build Hostel > Dorm{B1,B2} with fixed ids.
fn setup(deps: context.Deps) -> Promise(OrganizationId) {
  use _ <- promise.await(support.truncate(deps.db))
  let orgs = organization_repo.new(deps.db)
  let assert Ok(s) = slug.new("bk-org")
  let assert Ok(oid) = organization.new_id("org_bk")
  let assert Ok(org) = organization.new(oid, s, "Org")
  use saved <- promise.await(orgs.save(org))
  let assert Ok(_) = saved

  use _ <- promise.await(mk(deps, "sp_hostel", oid, None, True, "hostel", True))
  use _ <- promise.await(mk(
    deps,
    "sp_dorm",
    oid,
    Some("sp_hostel"),
    True,
    "dorm",
    True,
  ))
  use _ <- promise.await(mk(
    deps,
    "sp_b1",
    oid,
    Some("sp_dorm"),
    False,
    "bed",
    True,
  ))
  use _ <- promise.await(mk(
    deps,
    "sp_b2",
    oid,
    Some("sp_dorm"),
    False,
    "bed",
    True,
  ))
  promise.resolve(oid)
}

fn mk(
  deps: context.Deps,
  id: String,
  oid: OrganizationId,
  parent: Option(String),
  grouping: Bool,
  label: String,
  bookable: Bool,
) -> Promise(Nil) {
  let assert Ok(sid) = space.new_id(id)
  let pid = case parent {
    None -> None
    Some(p) -> {
      let assert Ok(x) = space.new_id(p)
      Some(x)
    }
  }
  let assert Ok(kind) = case grouping {
    True -> space.grouping(label)
    False -> space.unit(label)
  }
  let assert Ok(sp) = space.new(sid, oid, pid, kind, id, bookable)
  use saved <- promise.map(space_repo.new(deps.db).save(sp))
  let assert Ok(_) = saved
  Nil
}

pub fn dorm_capacity_is_enforced_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(_) = r1
  use r2 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(_) = r2
  use r3 <- promise.map(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  assert r3 == Error(create_booking.OverCapacity)
}

pub fn pins_and_holds_share_capacity_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [whole_item("sp_b1", d1, d3)]))
  let assert Ok(_) = r1
  use r2 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(_) = r2
  use r3 <- promise.map(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  assert r3 == Error(create_booking.OverCapacity)
}

pub fn pinned_bed_overlap_is_unavailable_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [whole_item("sp_b1", d1, d3)]))
  let assert Ok(_) = r1
  use r2 <- promise.map(book(deps, oid, [whole_item("sp_b1", d2, d4)]))
  assert r2 == Error(create_booking.Unavailable)
}

pub fn adjacent_dates_do_not_conflict_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [whole_item("sp_b1", d1, d2)]))
  let assert Ok(_) = r1
  use r2 <- promise.map(book(deps, oid, [whole_item("sp_b1", d2, d3)]))
  let assert Ok(_) = r2
}

pub fn whole_dorm_needs_empty_then_blocks_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [whole_item("sp_dorm", d1, d3)]))
  let assert Ok(_) = r1
  // the dorm is now fully consumed; a bed in it is over capacity
  use r2 <- promise.map(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  assert r2 == Error(create_booking.OverCapacity)
}

pub fn whole_hostel_consumes_nested_dorm_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [whole_item("sp_hostel", d1, d3)]))
  let assert Ok(_) = r1
  use left <- promise.await(booking_repo.new(deps.db).beds_left(
    a_space("sp_dorm"),
    a_period(d1, d3),
  ))
  assert left == Ok(0)
  use r2 <- promise.map(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  assert r2 == Error(create_booking.OverCapacity)
}

pub fn beds_left_reflects_holds_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  let repo = booking_repo.new(deps.db)
  use before <- promise.await(repo.beds_left(
    a_space("sp_dorm"),
    a_period(d1, d3),
  ))
  assert before == Ok(2)
  use _ <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  use after <- promise.map(repo.beds_left(a_space("sp_dorm"), a_period(d1, d3)))
  assert after == Ok(1)
}

pub fn cancel_frees_capacity_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  use r1 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(b1) = r1
  use r2 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(_) = r2
  // capacity 2 is full; a third is refused
  use r3 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  assert r3 == Error(create_booking.OverCapacity)
  // cancel the first, freeing a bed
  let id = booking.booking_id(booking.id(b1))
  use cancelled <- promise.await(transition_booking.run(
    booking_repo.new(deps.db),
    id,
    transition_booking.Cancel,
  ))
  let assert Ok(_) = cancelled
  use r4 <- promise.map(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(_) = r4
}

pub fn unit_in_non_room_type_is_rejected_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  // the hostel has a grouping child, so it is not a one-level room-type
  use r <- promise.map(book(deps, oid, [unit_item("sp_hostel", d1, d3)]))
  assert r == Error(create_booking.NotARoomType)
}

pub fn assign_picks_a_free_bed_test() {
  let deps = support.test_deps()
  use oid <- promise.await(setup(deps))
  let repo = booking_repo.new(deps.db)
  use r1 <- promise.await(book(deps, oid, [unit_item("sp_dorm", d1, d3)]))
  let assert Ok(bk) = r1
  let bid = booking.booking_id(booking.id(bk))
  use items <- promise.await(repo.list_items(booking.id(bk)))
  let assert Ok([item]) = items
  let item_id = booking_item.booking_item_id(booking_item.id(item))
  use assigned <- promise.map(app_assign(deps, bid, item_id))
  let assert Ok(updated) = assigned
  // assigned to one of the dorm's beds
  let bed = booking_item.assigned(updated)
  assert bed == Some(a_space("sp_b1")) || bed == Some(a_space("sp_b2"))
}

fn app_assign(deps: context.Deps, booking_id: String, item_id: String) {
  assign_booking_item.run(booking_repo.new(deps.db), booking_id, item_id, None)
}
