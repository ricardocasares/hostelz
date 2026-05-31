//// Unit tests for the register-user use case, using a fake `UserRepo`. The key
//// case: a unique-email violation surfaces as `RepoError.Conflict` and is
//// mapped to `EmailTaken`.

import app/register_user
import domain/user
import domain/user_repo.{UserRepo}
import gleam/javascript/promise

fn gen(id: String) -> fn() -> String {
  fn() { id }
}

fn repo_with_save(
  save: fn(user.User) -> promise.Promise(Result(Nil, user_repo.RepoError)),
) -> user_repo.UserRepo {
  UserRepo(
    save: save,
    find: fn(_) { promise.resolve(Error(user_repo.NotFound)) },
    find_by_email: fn(_) { promise.resolve(Error(user_repo.NotFound)) },
    list_all: fn() { promise.resolve(Ok([])) },
  )
}

fn ok_repo() -> user_repo.UserRepo {
  repo_with_save(fn(_) { promise.resolve(Ok(Nil)) })
}

fn conflict_repo() -> user_repo.UserRepo {
  repo_with_save(fn(_) {
    promise.resolve(Error(user_repo.Conflict("email already registered")))
  })
}

pub fn register_succeeds_test() {
  use result <- promise.map(register_user.run(
    ok_repo(),
    gen("u_1"),
    "ada@example.com",
    "Ada",
  ))
  let assert Ok(u) = result
  assert user.name(u) == "Ada"
  assert user.user_id(user.id(u)) == "u_1"
}

pub fn register_rejects_bad_email_test() {
  use result <- promise.map(register_user.run(
    ok_repo(),
    gen("u_1"),
    "nope",
    "Ada",
  ))
  let assert Error(register_user.InvalidEmail(_)) = result
}

pub fn register_rejects_empty_name_test() {
  use result <- promise.map(register_user.run(
    ok_repo(),
    gen("u_1"),
    "ada@example.com",
    "  ",
  ))
  assert result == Error(register_user.InvalidUser(user.EmptyName))
}

pub fn duplicate_email_is_email_taken_test() {
  use result <- promise.map(register_user.run(
    conflict_repo(),
    gen("u_1"),
    "ada@example.com",
    "Ada",
  ))
  assert result == Error(register_user.EmailTaken)
}
