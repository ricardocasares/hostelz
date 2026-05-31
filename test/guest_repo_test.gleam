//// Unit tests for the one piece of the Postgres adapter with real branching:
//// reconstructing a domain `Guest` from stored column values. These are pure
//// (no database) — they exercise the re-validation that turns a bad row into a
//// `Corrupt` error, including the org reference and the optional user link.

import db/guest_repo
import domain/email
import domain/guest
import domain/repo_error as port
import domain/user
import gleam/option.{None, Some}

pub fn reconstruct_valid_walk_in_row_test() {
  let assert Ok(g) =
    guest_repo.reconstruct("g1", "org_1", None, "Ada", "ada@example.com")
  assert guest.name(g) == "Ada"
  assert email.to_string(guest.email(g)) == "ada@example.com"
  assert guest.user_id(g) == None
}

pub fn reconstruct_valid_registered_row_test() {
  let assert Ok(g) =
    guest_repo.reconstruct("g1", "org_1", Some("u_1"), "Ada", "ada@example.com")
  let assert Ok(uid) = user.new_id("u_1")
  assert guest.user_id(g) == Some(uid)
}

pub fn reconstruct_trims_id_test() {
  let assert Ok(g) =
    guest_repo.reconstruct("  g1  ", "org_1", None, "Ada", "ada@example.com")
  assert guest.guest_id(guest.id(g)) == "g1"
}

pub fn reconstruct_bad_email_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("g1", "org_1", None, "Ada", "not-an-email")
}

pub fn reconstruct_empty_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("", "org_1", None, "Ada", "ada@example.com")
}

pub fn reconstruct_empty_org_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("g1", "", None, "Ada", "ada@example.com")
}

pub fn reconstruct_empty_user_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("g1", "org_1", Some(""), "Ada", "ada@example.com")
}

pub fn reconstruct_empty_name_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("g1", "org_1", None, "  ", "ada@example.com")
}
