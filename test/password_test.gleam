import auth/password
import gleam/javascript/promise

pub fn accepts_long_enough_test() {
  assert password.validate("password123") == Ok(Nil)
}

pub fn rejects_short_test() {
  assert password.validate("short") == Error(password.TooShort)
}

pub fn rejects_empty_test() {
  assert password.validate("") == Error(password.TooShort)
}

pub fn hash_round_trips_test() {
  use hash <- promise.await(password.hash("password123"))
  use ok <- promise.map(password.verify("password123", hash))
  assert ok == True
}

pub fn wrong_password_does_not_verify_test() {
  use hash <- promise.await(password.hash("password123"))
  use ok <- promise.map(password.verify("not-it", hash))
  assert ok == False
}
