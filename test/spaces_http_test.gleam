//// HTTP-layer tests for the nested space routes. Prerequisites (the owning org,
//// a parent space) are seeded via the repos, then the endpoint is exercised
//// over HTTP. Touches the database — run with the test DB.

import brioche/sql as db
import conversation.{type JsRequest, type RequestBody, Text}
import db/organization_repo
import db/space_repo
import domain/organization
import domain/slug
import domain/space
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/javascript/promise
import gleam/option.{None}
import gleam/string
import router
import router/context

@external(javascript, "./request_ffi.mjs", "request")
fn js_request(method: String, url: String, body: String) -> JsRequest

/// Fixed id generator so a created space's id is predictable in assertions.
fn test_deps() -> context.Deps {
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  context.Deps(db: conn, generate_id: fn() { "sp_http_test" })
}

fn req(method: String, path: String, body: String) -> Request(RequestBody) {
  conversation.to_gleam_request(js_request(method, "http://test" <> path, body))
}

fn truncate(conn: db.Connection) -> promise.Promise(Nil) {
  use _ <- promise.map(
    db.query("truncate table spaces, guests, organizations, users cascade")
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

fn seed_org(conn: db.Connection) -> promise.Promise(Nil) {
  let orgs = organization_repo.new(conn)
  let assert Ok(s) = slug.new("http-spaces")
  let assert Ok(oid) = organization.new_id("org_http_sp")
  let assert Ok(org) = organization.new(oid, s, "HTTP Spaces")
  use saved <- promise.map(orgs.save(org))
  let assert Ok(_) = saved
  Nil
}

fn seed_space(conn: db.Connection, id: String, is_grouping: Bool) -> promise.Promise(Nil) {
  let repo = space_repo.new(conn)
  let assert Ok(oid) = organization.new_id("org_http_sp")
  let assert Ok(sid) = space.new_id(id)
  let assert Ok(k) = case is_grouping {
    True -> space.grouping("room")
    False -> space.unit("bed")
  }
  let assert Ok(s) = space.new(sid, oid, None, k, "Seeded")
  use saved <- promise.map(repo.save(s))
  let assert Ok(_) = saved
  Nil
}

pub fn post_root_space_returns_201_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http_sp/spaces",
      "{\"name\":\"Main\",\"kind\":\"grouping\",\"label\":\"hostel\"}",
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"id\":\"sp_http_test\"")
  assert string.contains(body, "\"parent_id\":null")
  assert string.contains(body, "\"kind\":\"grouping\"")
}

pub fn post_child_under_grouping_returns_201_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use _ <- promise.await(seed_space(deps.db, "sp_parent", True))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http_sp/spaces",
      "{\"name\":\"Bed 1\",\"kind\":\"unit\",\"label\":\"bed\",\"parent_id\":\"sp_parent\"}",
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"parent_id\":\"sp_parent\"")
  assert string.contains(body, "\"kind\":\"unit\"")
}

pub fn post_child_under_unit_returns_422_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use _ <- promise.await(seed_space(deps.db, "sp_unit", False))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http_sp/spaces",
      "{\"name\":\"Bed 2\",\"kind\":\"unit\",\"label\":\"bed\",\"parent_id\":\"sp_unit\"}",
    ),
  ))
  assert res.status == 422
}

pub fn post_space_unknown_org_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_missing/spaces",
      "{\"name\":\"Main\",\"kind\":\"grouping\",\"label\":\"hostel\"}",
    ),
  ))
  assert res.status == 404
}

pub fn post_space_unknown_parent_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http_sp/spaces",
      "{\"name\":\"Bed\",\"kind\":\"unit\",\"label\":\"bed\",\"parent_id\":\"sp_nope\"}",
    ),
  ))
  assert res.status == 404
}

pub fn post_space_invalid_kind_returns_422_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req(
      "POST",
      "/api/organizations/org_http_sp/spaces",
      "{\"name\":\"X\",\"kind\":\"bogus\",\"label\":\"x\"}",
    ),
  ))
  assert res.status == 422
}

pub fn post_space_wrong_shape_returns_422_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations/org_http_sp/spaces", "{\"name\":\"X\"}"),
  ))
  assert res.status == 422
}

pub fn post_space_invalid_json_returns_400_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("POST", "/api/organizations/org_http_sp/spaces", "not json"),
  ))
  assert res.status == 400
}

pub fn get_org_spaces_returns_200_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use res <- promise.map(router.handle(
    deps,
    req("GET", "/api/organizations/org_http_sp/spaces", ""),
  ))
  assert res.status == 200
}

pub fn get_space_children_returns_200_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use _ <- promise.await(seed_org(deps.db))
  use _ <- promise.await(seed_space(deps.db, "sp_parent", True))
  use res <- promise.map(router.handle(
    deps,
    req("GET", "/api/spaces/sp_parent/children", ""),
  ))
  assert res.status == 200
}

pub fn show_unknown_space_returns_404_test() {
  let deps = test_deps()
  use _ <- promise.await(truncate(deps.db))
  use res <- promise.map(router.handle(deps, req("GET", "/api/spaces/nope", "")))
  assert res.status == 404
}

pub fn wrong_method_returns_405_test() {
  let deps = test_deps()
  use res <- promise.map(router.handle(deps, req("DELETE", "/api/spaces/x", "")))
  assert res.status == 405
}
