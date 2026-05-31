//// Integration test proving slug uniqueness against the real database — both
//// at the adapter (`Conflict`) and through the use case (`SlugTaken`).
//// Requires the test DB.

import app/create_organization
import brioche/sql as db
import db/membership_repo
import db/organization_repo as repo
import db/role_repo
import db/user_repo
import domain/email
import domain/organization
import domain/repo_error
import domain/slug
import domain/user
import gleam/dynamic/decode
import gleam/javascript/promise

fn connect() -> db.Connection {
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  conn
}

fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query(
      "truncate table memberships, role_permissions, roles, sessions, user_credentials, spaces, guests, organizations, users cascade",
    )
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

  let assert Ok(oid2) = organization.new_id("org_dup_2")
  let assert Ok(org2) = organization.new(oid2, s, "Second")
  use saved2 <- promise.map(orgs.save(org2))
  let assert Error(repo_error.Conflict(_)) = saved2
}

pub fn duplicate_slug_is_slug_taken_through_use_case_test() {
  let conn = connect()
  use _ <- promise.await(truncate(conn))

  // an owner for the orgs
  let assert Ok(uid) = user.new_id("u_org")
  let assert Ok(addr) = email.new("org@example.com")
  let assert Ok(u) = user.new(uid, addr, "Owner")
  use user_saved <- promise.await(user_repo.new(conn).save(u))
  let assert Ok(_) = user_saved

  let orgs = repo.new(conn)
  let roles = role_repo.new(conn)
  let memberships = membership_repo.new(conn)
  use first <- promise.await(create_organization.run(
    orgs,
    roles,
    memberships,
    fn() { "org_cdup_1" },
    uid,
    "backpackers",
    "First",
  ))
  let assert Ok(_) = first

  use second <- promise.map(create_organization.run(
    orgs,
    roles,
    memberships,
    fn() { "org_cdup_2" },
    uid,
    "backpackers",
    "Second",
  ))
  assert second == Error(create_organization.SlugTaken)
}
