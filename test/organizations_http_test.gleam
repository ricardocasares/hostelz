//// HTTP-layer tests for the organization routes, including the slug-uniqueness
//// contract at the wire: a duplicate slug is a 409, an invalid slug a 422.
//// Uses a real (unique) id generator so two creates with the same slug get
//// distinct ids — the conflict comes from the slug, not the id.
////
//// Touches the database — run with the test DB.

import brioche/sql as db
import conversation.{type JsRequest, type RequestBody, Text}
import glanoid
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/javascript/promise
import gleam/string
import router
import router/context

@external(javascript, "./request_ffi.mjs", "request")
fn js_request(method: String, url: String, body: String) -> JsRequest

fn test_deps() -> context.Deps {
  // One connection per pool — see the suite-wide note in guests_http_test.
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  let assert Ok(nanoid) = glanoid.make_generator(glanoid.default_alphabet)
  context.Deps(db: conn, generate_id: fn() { nanoid(21) })
}

fn req(method: String, path: String, body: String) -> Request(RequestBody) {
  conversation.to_gleam_request(js_request(method, "http://test" <> path, body))
}

fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query("truncate table guests, organizations, users cascade")
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

pub fn post_organization_returns_201_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations",
      "{\"name\":\"Backpackers\",\"slug\":\"backpackers\"}",
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"slug\":\"backpackers\"")
  assert string.contains(body, "\"name\":\"Backpackers\"")
}

pub fn post_duplicate_slug_returns_409_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use first <- promise.await(router.handle(
    deps,
    req("POST", "/api/organizations", "{\"name\":\"A\",\"slug\":\"dup\"}"),
  ))
  assert first.status == 201
  use second <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations", "{\"name\":\"B\",\"slug\":\"dup\"}"),
  ))
  assert second.status == 409
}

pub fn post_invalid_slug_returns_422_test() {
  let deps = test_deps()
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations", "{\"name\":\"A\",\"slug\":\"Bad Slug\"}"),
  ))
  assert res.status == 422
}

pub fn post_wrong_shape_returns_422_test() {
  let deps = test_deps()
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations", "{\"name\":\"A\"}"),
  ))
  assert res.status == 422
}

pub fn post_invalid_json_returns_400_test() {
  let deps = test_deps()
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations", "not json"),
  ))
  assert res.status == 400
}

pub fn get_organizations_returns_200_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("GET", "/api/organizations", ""),
  ))
  assert res.status == 200
}

pub fn show_unknown_organization_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("GET", "/api/organizations/nope", ""),
  ))
  assert res.status == 404
}
