//// Unit tests for the register-guest use case. They use a hand-rolled fake
//// `GuestRepo` (the payoff of the port being a record of functions) and a stub
//// id generator, so the validation and error-wrapping can be tested with no
//// database and no randomness.

import app/register_guest
import domain/guest
import domain/guest_repo.{GuestRepo}
import gleam/javascript/promise

/// A fake repo whose `save` always succeeds — enough to drive the use case
/// without storage. For the invalid-input cases below, `save` is never reached.
fn ok_repo() -> guest_repo.GuestRepo {
  GuestRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(Error(guest_repo.NotFound)) },
    list_all: fn() { promise.resolve(Ok([])) },
  )
}

/// A stub id generator that always yields the same id.
fn gen(id: String) -> fn() -> String {
  fn() { id }
}

pub fn register_rejects_empty_generated_id_test() {
  // A generator that returns "" must be rejected by the domain.
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen(""),
    "Ada",
    "ada@example.com",
  ))
  assert result == Error(register_guest.InvalidGuest(guest.EmptyId))
}

pub fn register_rejects_bad_email_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    "Ada",
    "nope",
  ))
  let assert Error(register_guest.InvalidEmail(_)) = result
}

pub fn register_rejects_empty_name_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    "  ",
    "ada@example.com",
  ))
  assert result == Error(register_guest.InvalidGuest(guest.EmptyName))
}

pub fn register_succeeds_with_valid_input_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    "Ada",
    "ada@example.com",
  ))
  let assert Ok(g) = result
  assert guest.name(g) == "Ada"
  assert guest.guest_id(guest.id(g)) == "g1"
}
