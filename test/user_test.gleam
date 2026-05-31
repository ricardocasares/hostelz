import domain/email
import domain/user

fn an_email() -> email.Email {
  let assert Ok(e) = email.new("ada@example.com")
  e
}

pub fn new_id_rejects_empty_test() {
  assert user.new_id("") == Error(user.EmptyId)
}

pub fn new_user_is_accepted_test() {
  let assert Ok(id) = user.new_id("u_1")
  let assert Ok(u) = user.new(id, an_email(), "Ada")
  assert user.name(u) == "Ada"
  assert email.to_string(user.email(u)) == "ada@example.com"
}

pub fn empty_name_is_rejected_test() {
  let assert Ok(id) = user.new_id("u_1")
  assert user.new(id, an_email(), "  ") == Error(user.EmptyName)
}

pub fn change_email_keeps_identity_test() {
  let assert Ok(id) = user.new_id("u_1")
  let assert Ok(u) = user.new(id, an_email(), "Ada")
  let assert Ok(other) = email.new("ada2@example.com")
  let updated = user.change_email(u, other)
  assert user.same_user(u, updated)
  assert email.to_string(user.email(updated)) == "ada2@example.com"
}

pub fn same_user_compares_by_id_test() {
  let assert Ok(id) = user.new_id("u_1")
  let assert Ok(a) = user.new(id, an_email(), "Ada")
  let assert Ok(b) = user.new(id, an_email(), "Ada Lovelace")
  assert user.same_user(a, b)
}
