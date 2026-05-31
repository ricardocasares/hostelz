//// HTTP-layer tests for `POST /api/guests`. The whole stack runs — middleware,
//// routing, decoding, the use case — by feeding `router.handle` a real web
//// `Request` built in `request_ffi.mjs` (conversation's `RequestBody` is opaque,
//// so it can't be built from Gleam). gleeunit awaits the returned `Promise`.
////
//// The 400/422/405 cases never touch the database (they fail before any query),
//// so they pass without one. The 201 case does persist — run with the test DB:
////
////   DATABASE_URL=postgres://rick@localhost:5432/hostelix_test gleam test

import brioche/sql as db
import conversation.{type JsRequest, type RequestBody, Text}
import gleam/http/request.{type Request}
import gleam/javascript/promise
import gleam/string
import router
import router/context

@external(javascript, "./request_ffi.mjs", "request")
fn js_request(method: String, url: String, body: String) -> JsRequest

/// Deps with a lazy connection and a *fixed* id generator, so the created
/// guest's id is predictable in assertions.
fn test_deps() -> context.Deps {
  let assert Ok(conn) = db.connect(db.default_config())
  context.Deps(db: conn, generate_id: fn() { "g_http_test" })
}

fn req(method: String, path: String, body: String) -> Request(RequestBody) {
  conversation.to_gleam_request(js_request(method, "http://test" <> path, body))
}

pub fn post_valid_guest_returns_201_test() {
  use res <- promise.map(router.handle(
    test_deps(),
    req(
      "POST",
      "/api/guests",
      "{\"name\":\"Ada\",\"email\":\"ada@example.com\"}",
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  // the server-minted id is echoed back
  assert string.contains(body, "\"id\":\"g_http_test\"")
  assert string.contains(body, "\"name\":\"Ada\"")
}

pub fn post_invalid_json_returns_400_test() {
  use res <- promise.map(router.handle(
    test_deps(),
    req("POST", "/api/guests", "not json"),
  ))
  assert res.status == 400
}

pub fn post_wrong_shape_returns_422_test() {
  use res <- promise.map(router.handle(
    test_deps(),
    req("POST", "/api/guests", "{\"name\":\"Ada\"}"),
  ))
  assert res.status == 422
}

pub fn post_bad_email_returns_422_test() {
  use res <- promise.map(router.handle(
    test_deps(),
    req("POST", "/api/guests", "{\"name\":\"Ada\",\"email\":\"nope\"}"),
  ))
  assert res.status == 422
  let assert Text(body) = res.body
  assert string.contains(body, "@")
}

pub fn wrong_method_returns_405_test() {
  use res <- promise.map(router.handle(
    test_deps(),
    req("GET", "/api/guests", ""),
  ))
  assert res.status == 405
}

pub fn unknown_path_returns_405_test() {
  use res <- promise.map(router.handle(
    test_deps(),
    req("POST", "/api/nope", "{}"),
  ))
  assert res.status == 405
}
