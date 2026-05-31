//// HTTP-layer tests for the nested guest routes. The whole stack runs —
//// middleware, routing, decoding, the use cases — by feeding `router.handle` a
//// real web `Request`. Prerequisites (the owning org, an optional user) are
//// seeded directly via the repos, then the target endpoint is exercised over
//// HTTP. gleeunit awaits the returned `Promise`.
////
//// These touch the database — run with the test DB:
////
////   DATABASE_URL=postgres://postgres@localhost:5432/hostelix_test gleam test

import brioche/sql as db
import conversation.{type JsRequest, type RequestBody, Text}
import db/organization_repo
import db/user_repo
import domain/email
import domain/organization
import domain/slug
import domain/user
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/javascript/promise
import gleam/string
import router
import router/context

@external(javascript, "./request_ffi.mjs", "request")
fn js_request(method: String, url: String, body: String) -> JsRequest

/// Deps with a lazy connection and a *fixed* id generator, so a created guest's
/// id is predictable in assertions.
fn test_deps() -> context.Deps {
  // One connection per pool: gleeunit has no teardown, so each test's pool
  // lingers — a larger pool would exhaust `max_connections` across the suite.
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  context.Deps(db: conn, generate_id: fn() { "g_http_test" })
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

fn seed_org(conn: db.Connection) -> promise.Promise(Nil) {
  let orgs = organization_repo.new(conn)
  let assert Ok(s) = slug.new("http-guests")
  let assert Ok(oid) = organization.new_id("org_http")
  let assert Ok(org) = organization.new(oid, s, "HTTP Guests")
  use saved <- promise.map(orgs.save(org))
  let assert Ok(_) = saved
  Nil
}

fn seed_user(conn: db.Connection) -> promise.Promise(Nil) {
  let users = user_repo.new(conn)
  let assert Ok(uid) = user.new_id("u_http")
  let assert Ok(mail) = email.new("ada-http@example.com")
  let assert Ok(u) = user.new(uid, mail, "Ada")
  use saved <- promise.map(users.save(u))
  let assert Ok(_) = saved
  Nil
}

pub fn post_walk_in_guest_returns_201_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\"}",
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"id\":\"g_http_test\"")
  assert string.contains(body, "\"organization_id\":\"org_http\"")
  assert string.contains(body, "\"user_id\":null")
}

pub fn post_registered_guest_returns_201_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use _ <- promise.await(seed_user(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http/guests",
      "{\"name\":\"Ada\",\"email\":\"ada2@example.com\",\"user_id\":\"u_http\"}",
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"user_id\":\"u_http\"")
}

pub fn post_guest_unknown_org_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_missing/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\"}",
    ),
  ))
  assert res.status == 404
}

pub fn post_guest_unknown_user_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\",\"user_id\":\"u_missing\"}",
    ),
  ))
  assert res.status == 404
}

pub fn post_guest_bad_email_returns_422_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http/guests",
      "{\"name\":\"Jo\",\"email\":\"nope\"}",
    ),
  ))
  assert res.status == 422
  let assert Text(body) = res.body
  assert string.contains(body, "@")
}

pub fn post_guest_wrong_shape_returns_422_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations/org_http/guests", "{\"name\":\"Jo\"}"),
  ))
  assert res.status == 422
}

pub fn post_guest_invalid_json_returns_400_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations/org_http/guests", "not json"),
  ))
  assert res.status == 400
}

pub fn get_org_guests_returns_200_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("GET", "/api/organizations/org_http/guests", ""),
  ))
  assert res.status == 200
}

pub fn show_unknown_guest_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(deps, req("GET", "/api/guests/nope", "")))
  assert res.status == 404
}

pub fn wrong_method_returns_405_test() {
  let deps = test_deps()
  use res <- promise.map(router.handle(deps, req("DELETE", "/api/guests/x", "")))
  assert res.status == 405
}

pub fn unknown_path_returns_405_test() {
  let deps = test_deps()
  use res <- promise.map(router.handle(deps, req("POST", "/api/nope", "{}")))
  assert res.status == 405
}
