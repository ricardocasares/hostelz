//// HTTP tests for the nested guest routes under authentication.

import conversation.{Text}
import gleam/javascript/promise
import gleam/string
import router
import support

pub fn post_walk_in_guest_returns_201_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\"}",
      token,
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"user_id\":null")
}

pub fn post_guest_unauthenticated_returns_401_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(_token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.req(
      "POST",
      "/api/organizations/" <> org_id <> "/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\"}",
    ),
  ))
  assert res.status == 401
}

pub fn post_guest_non_member_is_forbidden_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(_owner, org_id) <- promise.await(support.owner_setup(deps))
  use #(other_token, _uid) <- promise.await(support.user_with_session(
    deps,
    "outsider@example.com",
  ))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\"}",
      other_token,
    ),
  ))
  assert res.status == 403
}

pub fn post_guest_bad_email_returns_422_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/guests",
      "{\"name\":\"Jo\",\"email\":\"nope\"}",
      token,
    ),
  ))
  assert res.status == 422
}

pub fn get_org_guests_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/organizations/" <> org_id <> "/guests", "", token),
  ))
  assert res.status == 200
}

pub fn show_unknown_guest_returns_404_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/guests/nope", "", token),
  ))
  assert res.status == 404
}
