import domain/email.{type Email}
import gleam/string

pub opaque type GuestId {
  GuestId(value: String)
}

pub opaque type Guest {
  Guest(id: GuestId, name: String, email: Email)
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
  name: String,
  email: Email,
) -> Result(Guest, GuestError) {
  case string.trim(name) {
    "" -> Error(EmptyName)
    trimmed -> Ok(Guest(id, trimmed, email))
  }
}

// accessors
pub fn id(guest: Guest) -> GuestId {
  guest.id
}

pub fn guest_id(id: GuestId) -> String {
  id.value
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
  new(guest.id, new_name, guest.email)
}

pub fn change_email(guest: Guest, new_email: Email) -> Guest {
  Guest(guest.id, guest.name, new_email)
}

// identity equality — two guests are "the same" iff their ids match
pub fn same_guest(a: Guest, b: Guest) -> Bool {
  a.id == b.id
}
