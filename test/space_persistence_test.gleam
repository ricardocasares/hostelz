//// Integration tests against Postgres, through the create-space use case and
//// the adapter. Builds a hostel→room→bed tree, round-trips it, and proves the
//// leaf invariant (can't nest under a unit). Requires the test DB.

import app/create_space
import brioche/sql as db
import db/organization_repo
import db/space_repo as repo
import domain/organization.{type OrganizationId}
import domain/slug
import domain/space
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{None, Some}

fn connect() -> db.Connection {
  // One connection per pool — gleeunit has no teardown.
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  conn
}

fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query("truncate table spaces, guests, organizations, users cascade")
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

fn seed_org(
  conn: db.Connection,
  id: String,
  slug_str: String,
) -> promise.Promise(OrganizationId) {
  let orgs = organization_repo.new(conn)
  let assert Ok(s) = slug.new(slug_str)
  let assert Ok(oid) = organization.new_id(id)
  let assert Ok(org) = organization.new(oid, s, "Org")
  use saved <- promise.map(orgs.save(org))
  let assert Ok(_) = saved
  oid
}

pub fn space_tree_round_trip_test() {
  let conn = connect()
  let spaces = repo.new(conn)
  use _ <- promise.await(truncate(conn))
  use oid <- promise.await(seed_org(conn, "org_sp_1", "spaces-org-1"))

  // root grouping
  use r1 <- promise.await(create_space.run(
    spaces,
    fn() { "sp_hostel" },
    oid,
    None,
    True,
    "hostel",
    "Main Hostel",
    None,
  ))
  let assert Ok(hostel) = r1

  // room grouping under the hostel
  use r2 <- promise.await(create_space.run(
    spaces,
    fn() { "sp_room" },
    oid,
    Some(space.id(hostel)),
    True,
    "room",
    "Room 1",
    None,
  ))
  let assert Ok(room) = r2

  // bed unit under the room
  use r3 <- promise.await(create_space.run(
    spaces,
    fn() { "sp_bed" },
    oid,
    Some(space.id(room)),
    False,
    "bed",
    "Bed 1",
    None,
  ))
  let assert Ok(bed) = r3

  // find round-trips through the smart constructors
  use found <- promise.await(spaces.find(space.id(bed)))
  let assert Ok(b) = found
  assert space.parent_id(b) == Some(space.id(room))
  assert space.kind_is_grouping(space.kind(b)) == False

  // list_by_organization returns the whole tree
  use listed <- promise.await(spaces.list_by_organization(oid))
  let assert Ok(all) = listed
  assert list.length(all) == 3

  // children of the room = [bed]; children of the bed = []
  use room_kids <- promise.await(spaces.list_children(space.id(room)))
  let assert Ok(children) = room_kids
  assert list.length(children) == 1
  use bed_kids <- promise.await(spaces.list_children(space.id(bed)))
  let assert Ok(leaf) = bed_kids
  assert leaf == []

  promise.resolve(Nil)
}

pub fn cannot_nest_under_a_unit_test() {
  let conn = connect()
  let spaces = repo.new(conn)
  use _ <- promise.await(truncate(conn))
  use oid <- promise.await(seed_org(conn, "org_sp_2", "spaces-org-2"))

  use r1 <- promise.await(create_space.run(
    spaces,
    fn() { "sp_bed_x" },
    oid,
    None,
    False,
    "bed",
    "Bed",
    None,
  ))
  let assert Ok(bed) = r1

  // nesting a child under the bed (a unit) is rejected
  use r2 <- promise.map(create_space.run(
    spaces,
    fn() { "sp_child" },
    oid,
    Some(space.id(bed)),
    False,
    "bed",
    "Sub",
    None,
  ))
  assert r2 == Error(create_space.ParentNotGrouping)
}
