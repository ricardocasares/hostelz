//// Unit tests for the one piece of the Postgres adapter with real branching:
//// reconstructing a domain `Guest` from stored column values. These are pure
//// (no database) — they exercise the re-validation that turns a bad row into a
//// `Corrupt` error, which a real DB round-trip can't easily trigger because the
//// schema enforces NOT NULL text.

import db/guest_repo
import domain/email
import domain/guest
import domain/guest_repo as port

pub fn reconstruct_valid_row_test() {
  let assert Ok(g) = guest_repo.reconstruct("g1", "Ada", "ada@example.com")
  assert guest.name(g) == "Ada"
  assert email.to_string(guest.email(g)) == "ada@example.com"
}

pub fn reconstruct_trims_id_test() {
  let assert Ok(g) = guest_repo.reconstruct("  g1  ", "Ada", "ada@example.com")
  assert guest.guest_id(guest.id(g)) == "g1"
}

pub fn reconstruct_bad_email_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("g1", "Ada", "not-an-email")
}

pub fn reconstruct_empty_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("", "Ada", "ada@example.com")
}

pub fn reconstruct_empty_name_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    guest_repo.reconstruct("g1", "  ", "ada@example.com")
}
