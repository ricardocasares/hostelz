//// Unit tests for the reworked register-user use case (now sets a password and
//// stores a credential). Fake repos; password validation happens before IO.

import app/register_user
import domain/credential_repo.{CredentialRepo}
import domain/user
import domain/user_repo.{UserRepo}
import gleam/javascript/promise

fn gen(id: String) -> fn() -> String {
  fn() { id }
}

fn ok_users() -> user_repo.UserRepo {
  UserRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(Error(user_repo.NotFound)) },
    find_by_email: fn(_) { promise.resolve(Error(user_repo.NotFound)) },
    list_all: fn() { promise.resolve(Ok([])) },
  )
}

fn conflict_users() -> user_repo.UserRepo {
  UserRepo(
    ..ok_users(),
    save: fn(_) { promise.resolve(Error(user_repo.Conflict("dup"))) },
  )
}

fn ok_credentials() -> credential_repo.CredentialRepo {
  CredentialRepo(
    save: fn(_, _) { promise.resolve(Ok(Nil)) },
    find_hash: fn(_) { promise.resolve(Error(credential_repo.NotFound)) },
  )
}

pub fn register_succeeds_test() {
  use result <- promise.map(register_user.run(
    ok_users(),
    ok_credentials(),
    gen("u_1"),
    "ada@example.com",
    "Ada",
    "password123",
  ))
  let assert Ok(u) = result
  assert user.name(u) == "Ada"
}

pub fn register_rejects_short_password_test() {
  use result <- promise.map(register_user.run(
    ok_users(),
    ok_credentials(),
    gen("u_1"),
    "ada@example.com",
    "Ada",
    "short",
  ))
  let assert Error(register_user.InvalidPassword(_)) = result
}

pub fn register_rejects_bad_email_test() {
  use result <- promise.map(register_user.run(
    ok_users(),
    ok_credentials(),
    gen("u_1"),
    "nope",
    "Ada",
    "password123",
  ))
  let assert Error(register_user.InvalidEmail(_)) = result
}

pub fn register_rejects_empty_name_test() {
  use result <- promise.map(register_user.run(
    ok_users(),
    ok_credentials(),
    gen("u_1"),
    "ada@example.com",
    "  ",
    "password123",
  ))
  let assert Error(register_user.InvalidUser(_)) = result
}

pub fn duplicate_email_is_email_taken_test() {
  use result <- promise.map(register_user.run(
    conflict_users(),
    ok_credentials(),
    gen("u_1"),
    "ada@example.com",
    "Ada",
    "password123",
  ))
  assert result == Error(register_user.EmailTaken)
}
