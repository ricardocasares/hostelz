//// Integration tests against Postgres, through the use cases and the adapters.
//// Covers the guest↔organization (mandatory) and guest↔user (optional)
//// relationships, including the database foreign keys and a walk-in's NULL
//// user_id.
////
//// Requires a reachable database with the schema applied. Run with the test DB:
////
////   DATABASE_URL=postgres://postgres@localhost:5432/hostelix_test gleam test

import app/register_guest
import brioche/sql as db
import db/guest_repo as repo
import db/organization_repo as org_repo
import db/user_repo as usr_repo
import domain/email
import domain/guest
import domain/organization.{type OrganizationId}
import domain/repo_error
import domain/slug
import domain/user.{type UserId}
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{None, Some}

fn connect() -> db.Connection {
  // Cap the pool at one connection: gleeunit has no teardown, so every test's
  // pool lingers — a larger pool per test would exhaust `max_connections`.
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  conn
}

/// Start each run from clean tables (guests references organizations and users).
fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query("truncate table guests, organizations, users cascade")
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

fn seed_org(conn: db.Connection) -> promise.Promise(OrganizationId) {
  let orgs = org_repo.new(conn)
  let assert Ok(s) = slug.new("backpackers")
  let assert Ok(oid) = organization.new_id("org_int_1")
  let assert Ok(org) = organization.new(oid, s, "Backpackers")
  use saved <- promise.map(orgs.save(org))
  let assert Ok(_) = saved
  oid
}

fn seed_user(conn: db.Connection) -> promise.Promise(UserId) {
  let users = usr_repo.new(conn)
  let assert Ok(uid) = user.new_id("u_int_1")
  let assert Ok(mail) = email.new("ada@example.com")
  let assert Ok(u) = user.new(uid, mail, "Ada")
  use saved <- promise.map(users.save(u))
  let assert Ok(_) = saved
  uid
}

pub fn guest_round_trip_test() {
  let conn = connect()
  let guests = repo.new(conn)

  use _ <- promise.await(truncate(conn))
  use oid <- promise.await(seed_org(conn))
  use uid <- promise.await(seed_user(conn))

  // a walk-in guest (no linked user)
  use registered <- promise.await(register_guest.run(
    guests,
    fn() { "g_int_walk" },
    oid,
    None,
    "Jo",
    "jo@example.com",
  ))
  let assert Ok(walk_in) = registered

  // find round-trips back through the smart constructors
  use found <- promise.await(guests.find(guest.id(walk_in)))
  let assert Ok(g) = found
  assert guest.same_guest(g, walk_in)
  assert guest.organization_id(g) == oid
  assert guest.user_id(g) == None

  // a guest linked to the user account
  use registered2 <- promise.await(register_guest.run(
    guests,
    fn() { "g_int_reg" },
    oid,
    Some(uid),
    "Ada",
    "ada-guest@example.com",
  ))
  let assert Ok(registered_guest) = registered2
  use found2 <- promise.await(guests.find(guest.id(registered_guest)))
  let assert Ok(g2) = found2
  assert guest.user_id(g2) == Some(uid)

  // list_by_organization returns both, scoped to the org
  use listed <- promise.await(guests.list_by_organization(oid))
  let assert Ok(all) = listed
  assert list.length(all) == 2

  // a different org has none of them
  let assert Ok(other) = organization.new_id("org_int_other")
  use listed_other <- promise.await(guests.list_by_organization(other))
  let assert Ok(none_for_other) = listed_other
  assert none_for_other == []

  // upsert: same id, new name -> updates in place (still two rows total)
  use _ <- promise.await(register_guest.run(
    guests,
    fn() { "g_int_walk" },
    oid,
    None,
    "Jo Walker",
    "jo@example.com",
  ))
  use found3 <- promise.await(guests.find(guest.id(walk_in)))
  let assert Ok(g3) = found3
  assert guest.name(g3) == "Jo Walker"
  use relisted <- promise.await(guests.list_by_organization(oid))
  let assert Ok(still_two) = relisted
  assert list.length(still_two) == 2

  // unknown id -> NotFound
  let assert Ok(missing) = guest.new_id("g_missing")
  use nf <- promise.await(guests.find(missing))
  assert nf == Error(repo_error.NotFound)

  promise.resolve(Nil)
}

pub fn guest_with_unknown_organization_is_rejected_test() {
  let conn = connect()
  let guests = repo.new(conn)
  use _ <- promise.await(truncate(conn))

  // the org foreign key rejects a guest whose org does not exist
  let assert Ok(oid) = organization.new_id("org_does_not_exist")
  use result <- promise.map(register_guest.run(
    guests,
    fn() { "g_orphan" },
    oid,
    None,
    "Jo",
    "jo@example.com",
  ))
  let assert Error(register_guest.RepoFailed(_)) = result
}
