//// Integration tests for the auth/authz adapters against the real database:
//// credential + session round-trips, role/permission persistence, and the
//// owner count. Requires the test DB.

import app/create_organization
import auth/token
import brioche/sql as db
import db/credential_repo
import db/membership_repo
import db/organization_repo
import db/role_repo
import db/session_repo
import db/user_repo
import domain/email
import domain/organization
import domain/permission
import domain/role
import domain/session_repo as session_port
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

fn make_user(
  conn: db.Connection,
  id: String,
  email_str: String,
) -> promise.Promise(user.UserId) {
  let assert Ok(uid) = user.new_id(id)
  let assert Ok(addr) = email.new(email_str)
  let assert Ok(u) = user.new(uid, addr, "U")
  use saved <- promise.map(user_repo.new(conn).save(u))
  let assert Ok(_) = saved
  uid
}

pub fn credential_round_trip_test() {
  let conn = connect()
  use _ <- promise.await(truncate(conn))
  use uid <- promise.await(make_user(conn, "u_cred", "cred@example.com"))
  let creds = credential_repo.new(conn)
  use saved <- promise.await(creds.save(uid, "hashed-value"))
  let assert Ok(_) = saved
  use found <- promise.map(creds.find_hash(uid))
  assert found == Ok("hashed-value")
}

pub fn session_save_find_delete_test() {
  let conn = connect()
  use _ <- promise.await(truncate(conn))
  use uid <- promise.await(make_user(conn, "u_sess", "sess@example.com"))
  let sessions = session_repo.new(conn)
  let hash = token.hash("raw-token")
  use saved <- promise.await(sessions.save(hash, uid))
  let assert Ok(_) = saved
  use found <- promise.await(sessions.find_user(hash))
  assert found == Ok(uid)
  use _ <- promise.await(sessions.delete(hash))
  use gone <- promise.map(sessions.find_user(hash))
  assert gone == Error(session_port.NotFound)
}

pub fn role_permissions_round_trip_test() {
  let conn = connect()
  use _ <- promise.await(truncate(conn))
  let assert Ok(s) = slug.new("roleorg")
  let assert Ok(oid) = organization.new_id("o_role")
  let assert Ok(org) = organization.new(oid, s, "Org")
  use osaved <- promise.await(organization_repo.new(conn).save(org))
  let assert Ok(_) = osaved

  let roles = role_repo.new(conn)
  let assert Ok(rid) = role.new_id("r_fd")
  let assert Ok(r) =
    role.new(rid, oid, "Front Desk", [
      permission.GuestCreate,
      permission.GuestRead,
    ])
  use rsaved <- promise.await(roles.save(r))
  let assert Ok(_) = rsaved
  use found <- promise.map(roles.find(rid))
  let assert Ok(loaded) = found
  assert role.allows(loaded, permission.GuestCreate)
  assert role.allows(loaded, permission.SpaceCreate) == False
  assert role.is_owner(loaded) == False
}

pub fn create_org_seeds_one_owner_test() {
  let conn = connect()
  use _ <- promise.await(truncate(conn))
  use uid <- promise.await(make_user(conn, "u_owner", "owner2@example.com"))
  use created <- promise.await(create_organization.run(
    organization_repo.new(conn),
    role_repo.new(conn),
    membership_repo.new(conn),
    fn() { "co_1" },
    uid,
    "ownerorg",
    "Org",
  ))
  let assert Ok(org) = created
  use count <- promise.map(membership_repo.new(conn).count_owners(
    organization.id(org),
  ))
  assert count == Ok(1)
}
