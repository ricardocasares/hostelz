//// Password hashing and validation. Hashing/verification delegate to Bun's
//// built-in `Bun.password` (argon2id) via FFI — async, so they return
//// `Promise`. `validate` is a pure policy check applied before hashing.

import gleam/javascript/promise.{type Promise}
import gleam/string

pub type PasswordError {
  TooShort
}

const min_length = 8

/// Minimum password policy. Passwords are not trimmed — whitespace is allowed.
pub fn validate(plaintext: String) -> Result(Nil, PasswordError) {
  case string.length(plaintext) >= min_length {
    True -> Ok(Nil)
    False -> Error(TooShort)
  }
}

@external(javascript, "./password_ffi.mjs", "hash")
pub fn hash(plaintext: String) -> Promise(String)

@external(javascript, "./password_ffi.mjs", "verify")
pub fn verify(plaintext: String, hash: String) -> Promise(Bool)
