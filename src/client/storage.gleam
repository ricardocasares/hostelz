//// Browser bindings the client needs: the auth token in `localStorage`, and the
//// page origin so the API client can build absolute, same-origin URLs.

@external(javascript, "./storage_ffi.mjs", "readToken")
fn do_read_token() -> String

@external(javascript, "./storage_ffi.mjs", "writeToken")
pub fn write_token(token: String) -> Nil

@external(javascript, "./storage_ffi.mjs", "clearToken")
pub fn clear_token() -> Nil

/// The current page origin, e.g. `http://localhost:5173`. API URLs are built
/// from this so requests stay same-origin (proxied to the API in dev).
@external(javascript, "./storage_ffi.mjs", "origin")
pub fn origin() -> String

/// The persisted bearer token, or `Error(Nil)` when none is stored.
pub fn read_token() -> Result(String, Nil) {
  case do_read_token() {
    "" -> Error(Nil)
    token -> Ok(token)
  }
}
