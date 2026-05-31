//// Unit tests for the register-guest use case. A hand-rolled fake `GuestRepo`
//// (the payoff of the port being a record of functions) and a stub id generator
//// let the validation and error-wrapping be tested with no database and no
//// randomness. The owning org and optional user link are passed as already-
//// validated value objects.

import app/register_guest
import domain/guest
import domain/guest_repo.{GuestRepo}
import domain/organization
import domain/user
import gleam/javascript/promise
import gleam/option.{None, Some}

fn ok_repo() -> guest_repo.GuestRepo {
  GuestRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(Error(guest_repo.NotFound)) },
    list_by_organization: fn(_) { promise.resolve(Ok([])) },
  )
}

fn gen(id: String) -> fn() -> String {
  fn() { id }
}

fn an_org_id() -> organization.OrganizationId {
  let assert Ok(id) = organization.new_id("org_1")
  id
}

pub fn register_rejects_empty_generated_id_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen(""),
    an_org_id(),
    None,
    "Ada",
    "ada@example.com",
  ))
  assert result == Error(register_guest.InvalidGuest(guest.EmptyId))
}

pub fn register_rejects_bad_email_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    an_org_id(),
    None,
    "Ada",
    "nope",
  ))
  let assert Error(register_guest.InvalidEmail(_)) = result
}

pub fn register_rejects_empty_name_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    an_org_id(),
    None,
    "  ",
    "ada@example.com",
  ))
  assert result == Error(register_guest.InvalidGuest(guest.EmptyName))
}

pub fn register_walk_in_succeeds_test() {
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    an_org_id(),
    None,
    "Ada",
    "ada@example.com",
  ))
  let assert Ok(g) = result
  assert guest.name(g) == "Ada"
  assert guest.guest_id(guest.id(g)) == "g1"
  assert guest.user_id(g) == None
}

pub fn register_linked_to_user_succeeds_test() {
  let assert Ok(uid) = user.new_id("u_1")
  use result <- promise.map(register_guest.run(
    ok_repo(),
    gen("g1"),
    an_org_id(),
    Some(uid),
    "Ada",
    "ada@example.com",
  ))
  let assert Ok(g) = result
  assert guest.user_id(g) == Some(uid)
}
