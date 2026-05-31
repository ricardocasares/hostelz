//// Integration test: a real save -> find round-trip against Postgres, going
//// through the register-guest use case and the Postgres adapter.
////
//// Requires a reachable database with the `guests` table. Run with the test DB:
////
////   DATABASE_URL=postgres://rick@localhost:5432/hostelix_test gleam test
////
//// `default_config()` reads `DATABASE_URL`, so without it this test connects to
//// whatever Bun resolves (or fails).

import app/register_guest
import brioche/sql as db
import db/guest_repo as repo
import domain/email
import domain/guest
import domain/guest_repo
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list

fn connect() -> db.Connection {
  let assert Ok(conn) = db.connect(db.default_config())
  conn
}

/// Start each run from a clean table.
fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query("delete from guests")
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

pub fn guest_round_trip_test() {
  let conn = connect()
  let r = repo.new(conn)

  use _ <- promise.await(truncate(conn))

  // register = validate + save (an upsert), via the use case. A fixed id
  // generator lets us assert the upsert below updates the same row.
  use registered <- promise.await(register_guest.run(
    r,
    fn() { "g_int_1" },
    "Ada",
    "ada@example.com",
  ))
  let assert Ok(saved) = registered

  // find round-trips back through the smart constructors
  use found <- promise.await(r.find(guest.id(saved)))
  let assert Ok(g) = found
  assert guest.same_guest(g, saved)
  assert guest.name(g) == "Ada"
  assert email.to_string(guest.email(g)) == "ada@example.com"

  // upsert: same id, new name -> updates in place (still one row)
  use _ <- promise.await(register_guest.run(
    r,
    fn() { "g_int_1" },
    "Ada Lovelace",
    "ada@example.com",
  ))
  use found2 <- promise.await(r.find(guest.id(saved)))
  let assert Ok(g2) = found2
  assert guest.name(g2) == "Ada Lovelace"

  use listed <- promise.await(r.list_all())
  let assert Ok(all) = listed
  assert list.length(all) == 1

  // unknown id -> NotFound
  let assert Ok(missing) = guest.new_id("g_missing")
  use nf <- promise.await(r.find(missing))
  assert nf == Error(guest_repo.NotFound)

  promise.resolve(Nil)
}
