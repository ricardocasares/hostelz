//// Integration test proving slug uniqueness against the real database — the
//// authoritative guard. The `Slug` value object only validates *format*;
//// *uniqueness* across all organizations is enforced by the `organizations_slug_key`
//// unique index, surfaced by the adapter as `Conflict` and by the use case as
//// `SlugTaken`.
////
//// Requires the test DB (see guest_persistence_test).

import app/create_organization
import brioche/sql as db
import db/organization_repo as repo
import domain/organization
import domain/organization_repo
import domain/slug
import gleam/dynamic/decode
import gleam/javascript/promise

fn connect() -> db.Connection {
  // One connection per pool — see guest_persistence_test for why.
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  conn
}

fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query("truncate table guests, organizations, users cascade")
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

pub fn duplicate_slug_is_conflict_at_adapter_test() {
  let conn = connect()
  let orgs = repo.new(conn)
  use _ <- promise.await(truncate(conn))

  let assert Ok(s) = slug.new("backpackers")
  let assert Ok(oid1) = organization.new_id("org_dup_1")
  let assert Ok(org1) = organization.new(oid1, s, "First")
  use saved1 <- promise.await(orgs.save(org1))
  let assert Ok(_) = saved1

  // a different id, the same slug -> the unique index must reject it
  let assert Ok(oid2) = organization.new_id("org_dup_2")
  let assert Ok(org2) = organization.new(oid2, s, "Second")
  use saved2 <- promise.map(orgs.save(org2))
  let assert Error(organization_repo.Conflict(_)) = saved2
}

pub fn duplicate_slug_is_slug_taken_through_use_case_test() {
  let conn = connect()
  let orgs = repo.new(conn)
  use _ <- promise.await(truncate(conn))

  use first <- promise.await(create_organization.run(
    orgs,
    fn() { "org_cdup_1" },
    "backpackers",
    "First",
  ))
  let assert Ok(_) = first

  // different generated id, same slug -> SlugTaken
  use second <- promise.map(create_organization.run(
    orgs,
    fn() { "org_cdup_2" },
    "backpackers",
    "Second",
  ))
  assert second == Error(create_organization.SlugTaken)
}
