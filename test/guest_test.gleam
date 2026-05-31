import domain/email
import domain/guest
import domain/organization
import domain/user
import gleam/option.{None, Some}

fn an_email() -> email.Email {
  let assert Ok(e) = email.new("ada@example.com")
  e
}

fn an_org_id() -> organization.OrganizationId {
  let assert Ok(id) = organization.new_id("org_1")
  id
}

fn a_user_id() -> user.UserId {
  let assert Ok(id) = user.new_id("u_1")
  id
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
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  assert guest.name(g) == "Ada"
}

pub fn new_guest_is_a_walk_in_by_default_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  assert guest.user_id(g) == None
}

pub fn new_guest_belongs_to_its_organization_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  assert guest.organization_id(g) == an_org_id()
}

pub fn new_guest_can_be_linked_to_a_user_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) =
    guest.new(id, an_org_id(), Some(a_user_id()), "Ada", an_email())
  assert guest.user_id(g) == Some(a_user_id())
}

pub fn new_guest_trims_name_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "  Ada  ", an_email())
  assert guest.name(g) == "Ada"
}

pub fn empty_name_is_rejected_test() {
  let assert Ok(id) = guest.new_id("g_123")
  assert guest.new(id, an_org_id(), None, "  ", an_email())
    == Error(guest.EmptyName)
}

// --- transitions ---

pub fn rename_updates_name_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  let assert Ok(renamed) = guest.rename(g, "Ada Lovelace")
  assert guest.name(renamed) == "Ada Lovelace"
}

pub fn rename_revalidates_name_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  assert guest.rename(g, "   ") == Error(guest.EmptyName)
}

pub fn change_email_keeps_identity_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  let assert Ok(other) = email.new("ada2@example.com")
  let updated = guest.change_email(g, other)
  assert guest.same_guest(g, updated)
  assert email.to_string(guest.email(updated)) == "ada2@example.com"
}

pub fn link_user_registers_a_walk_in_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(g) = guest.new(id, an_org_id(), None, "Ada", an_email())
  let linked = guest.link_user(g, a_user_id())
  assert guest.same_guest(g, linked)
  assert guest.user_id(linked) == Some(a_user_id())
}

// --- identity ---

pub fn same_guest_compares_by_id_test() {
  let assert Ok(id) = guest.new_id("g_123")
  let assert Ok(m1) = email.new("ada@example.com")
  let assert Ok(m2) = email.new("ada2@example.com")
  let assert Ok(a) = guest.new(id, an_org_id(), None, "Ada", m1)
  let assert Ok(b) = guest.new(id, an_org_id(), Some(a_user_id()), "Ada", m2)
  assert guest.same_guest(a, b)
}

pub fn different_ids_are_not_the_same_guest_test() {
  let assert Ok(id1) = guest.new_id("g_123")
  let assert Ok(id2) = guest.new_id("g_456")
  let assert Ok(a) = guest.new(id1, an_org_id(), None, "Ada", an_email())
  let assert Ok(b) = guest.new(id2, an_org_id(), None, "Ada", an_email())
  assert !guest.same_guest(a, b)
}
