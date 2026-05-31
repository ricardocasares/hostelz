import domain/email.{type Email}
import gleam/string

pub opaque type UserId {
  UserId(value: String)
}

pub opaque type User {
  User(id: UserId, email: Email, name: String)
}

pub type UserError {
  EmptyId
  EmptyName
}

pub fn new_id(raw: String) -> Result(UserId, UserError) {
  let raw = string.trim(raw)
  case string.is_empty(raw) {
    True -> Error(EmptyId)
    False -> Ok(UserId(raw))
  }
}

pub fn new(id: UserId, email: Email, name: String) -> Result(User, UserError) {
  case string.trim(name) {
    "" -> Error(EmptyName)
    trimmed -> Ok(User(id, email, trimmed))
  }
}

// accessors
pub fn id(user: User) -> UserId {
  user.id
}

pub fn user_id(id: UserId) -> String {
  id.value
}

pub fn email(user: User) -> Email {
  user.email
}

pub fn name(user: User) -> String {
  user.name
}

// state transitions return new immutable values (same identity)
pub fn rename(user: User, new_name: String) -> Result(User, UserError) {
  new(user.id, user.email, new_name)
}

pub fn change_email(user: User, new_email: Email) -> User {
  User(user.id, new_email, user.name)
}

// identity equality — two users are "the same" iff their ids match
pub fn same_user(a: User, b: User) -> Bool {
  a.id == b.id
}
