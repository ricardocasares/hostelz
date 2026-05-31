//// Unit tests for the user adapter's `reconstruct`. Pure, no database.

import db/user_repo
import domain/email
import domain/user
import domain/user_repo as port

pub fn reconstruct_valid_row_test() {
  let assert Ok(u) = user_repo.reconstruct("u_1", "ada@example.com", "Ada")
  assert user.name(u) == "Ada"
  assert email.to_string(user.email(u)) == "ada@example.com"
}

pub fn reconstruct_bad_email_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    user_repo.reconstruct("u_1", "nope", "Ada")
}

pub fn reconstruct_empty_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    user_repo.reconstruct("", "ada@example.com", "Ada")
}

pub fn reconstruct_empty_name_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    user_repo.reconstruct("u_1", "ada@example.com", "  ")
}
