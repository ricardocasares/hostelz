import domain/email
import domain/guest

fn an_email() -> email.Email {
  let assert Ok(e) = email.new("ada@example.com")
  e
}

// --- GuestId ---

pub fn new_id_rejects_empty_test() {
  assert guest.new_id("") == Error(guest.EmptyId)
}

pub fn new_id_rejects_whitespace_test() {
  assert guest.new_id("   ") == Error(guest.EmptyId)
}

pub fn new_id_trims_and_accepts_test() {
  let assert Ok(id) = guest.new_id("  g_123  ")
  assert guest.guest_id(id) == "g_123"
}

// --- construction ---

pub fn new_guest_is_accepted_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, "Ada", an_email())
  assert guest.name(g) == "Ada"
}

pub fn new_guest_trims_name_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, "  Ada  ", an_email())
  assert guest.name(g) == "Ada"
}

pub fn empty_name_is_rejected_test() {
  let assert Ok(id) = guest.new_id("g_123")
  assert guest.new(id, "  ", an_email()) == Error(guest.EmptyName)
}

// --- transitions ---

pub fn rename_updates_name_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, "Ada", an_email())
  let assert Ok(renamed) = guest.rename(g, "Ada Lovelace")
  assert guest.name(renamed) == "Ada Lovelace"
}

pub fn rename_revalidates_name_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, "Ada", an_email())
  assert guest.rename(g, "   ") == Error(guest.EmptyName)
}

pub fn change_email_keeps_identity_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, "Ada", an_email())
  let assert Ok(other) = email.new("ada2@example.com")
  let updated = guest.change_email(g, other)
  assert guest.same_guest(g, updated)
  assert email.to_string(guest.email(updated)) == "ada2@example.com"
}

// --- identity ---

pub fn same_guest_compares_by_id_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(m1) = email.new("ada@example.com")
  let assert Ok(m2) = email.new("ada2@example.com")
  let assert Ok(a) = guest.new(id, "Ada", m1)
  let assert Ok(b) = guest.new(id, "Ada Lovelace", m2)
  assert guest.same_guest(a, b)
}

pub fn different_ids_are_not_the_same_guest_test() {
  let assert Ok(id1) = guest.new_id("g_123")
  let assert Ok(id2) = guest.new_id("g_456")
  let assert Ok(a) = guest.new(id1, "Ada", an_email())
  let assert Ok(b) = guest.new(id2, "Ada", an_email())
  assert !guest.same_guest(a, b)
}
