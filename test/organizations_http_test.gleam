//// HTTP tests for the organization routes under authentication. Uses the
//// shared `support` helper for an authenticated user / owner + a Bearer token.

import conversation.{Text}
import gleam/javascript/promise
import gleam/string
import router
import support

pub fn post_unauthenticated_returns_401_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use res <- promise.map(router.handle(
    deps,
    support.req("POST", "/api/organizations", "{\"name\":\"A\",\"slug\":\"a\"}"),
  ))
  assert res.status == 401
}

pub fn post_organization_returns_201_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _user_id) <- promise.await(support.user_with_session(
    deps,
    "u@example.com",
  ))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations",
      "{\"name\":\"Acme\",\"slug\":\"acme\"}",
      token,
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"slug\":\"acme\"")
}

pub fn post_duplicate_slug_returns_409_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _user_id) <- promise.await(support.user_with_session(
    deps,
    "u@example.com",
  ))
  use first <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations",
      "{\"name\":\"A\",\"slug\":\"dup\"}",
      token,
    ),
  ))
  assert first.status == 201
  use second <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations",
      "{\"name\":\"B\",\"slug\":\"dup\"}",
      token,
    ),
  ))
  assert second.status == 409
}

pub fn post_invalid_slug_returns_422_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _user_id) <- promise.await(support.user_with_session(
    deps,
    "u@example.com",
  ))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations",
      "{\"name\":\"A\",\"slug\":\"Bad Slug\"}",
      token,
    ),
  ))
  assert res.status == 422
}

pub fn get_organizations_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/organizations", "", token),
  ))
  assert res.status == 200
}

pub fn show_my_org_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/organizations/" <> org_id, "", token),
  ))
  assert res.status == 200
}

pub fn show_foreign_org_is_forbidden_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/organizations/not-my-org", "", token),
  ))
  assert res.status == 403
}
