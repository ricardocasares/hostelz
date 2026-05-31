import domain/email.{type Email}
import domain/organization.{type OrganizationId}
import domain/user.{type UserId}
import gleam/option.{type Option, Some}
import gleam/string

pub opaque type GuestId {
  GuestId(value: String)
}

pub opaque type Guest {
  Guest(
    id: GuestId,
    organization_id: OrganizationId,
    user_id: Option(UserId),
    name: String,
    email: Email,
  )
}

pub type GuestError {
  EmptyId
  EmptyName
}

pub fn new_id(raw: String) -> Result(GuestId, GuestError) {
  let raw = string.trim(raw)
  case string.is_empty(raw) {
    True -> Error(EmptyId)
    False -> Ok(GuestId(raw))
  }
}

pub fn new(
  id: GuestId,
  organization_id: OrganizationId,
  user_id: Option(UserId),
  name: String,
  email: Email,
) -> Result(Guest, GuestError) {
  case string.trim(name) {
    "" -> Error(EmptyName)
    trimmed -> Ok(Guest(id, organization_id, user_id, trimmed, email))
  }
}

// accessors
pub fn id(guest: Guest) -> GuestId {
  guest.id
}

pub fn guest_id(id: GuestId) -> String {
  id.value
}

pub fn organization_id(guest: Guest) -> OrganizationId {
  guest.organization_id
}

pub fn user_id(guest: Guest) -> Option(UserId) {
  guest.user_id
}

pub fn name(guest: Guest) -> String {
  guest.name
}

pub fn email(guest: Guest) -> Email {
  guest.email
}

// state transitions return new immutable values (same identity)
pub fn rename(guest: Guest, new_name: String) -> Result(Guest, GuestError) {
  // reuse the smart constructor's validation
  new(guest.id, guest.organization_id, guest.user_id, new_name, guest.email)
}

pub fn change_email(guest: Guest, new_email: Email) -> Guest {
  Guest(..guest, email: new_email)
}

// link a walk-in guest to a system account (registration)
pub fn link_user(guest: Guest, user_id: UserId) -> Guest {
  Guest(..guest, user_id: Some(user_id))
}

// identity equality — two guests are "the same" iff their ids match
pub fn same_guest(a: Guest, b: Guest) -> Bool {
  a.id == b.id
}
