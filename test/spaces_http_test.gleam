//// HTTP tests for the nested space routes under authentication. The owner has
//// every permission; a non-member is forbidden.

import conversation.{Text}
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/json
import gleam/string
import router
import support

fn id_of(body: String) -> String {
  let assert Ok(id) =
    json.parse(body, {
      use id <- decode.field("id", decode.string)
      decode.success(id)
    })
  id
}

pub fn post_root_space_returns_201_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Main\",\"kind\":\"grouping\",\"label\":\"hostel\"}",
      token,
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"kind\":\"grouping\"")
}

pub fn post_child_under_grouping_returns_201_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use parent <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Room 1\",\"kind\":\"grouping\",\"label\":\"room\"}",
      token,
    ),
  ))
  let assert Text(parent_body) = parent.body
  let parent_id = id_of(parent_body)
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Bed 1\",\"kind\":\"unit\",\"label\":\"bed\",\"parent_id\":\""
        <> parent_id
        <> "\"}",
      token,
    ),
  ))
  assert res.status == 201
}

pub fn post_space_unauthenticated_returns_401_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(_token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.req(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Main\",\"kind\":\"grouping\",\"label\":\"hostel\"}",
    ),
  ))
  assert res.status == 401
}

pub fn post_space_non_member_is_forbidden_test() {
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
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Main\",\"kind\":\"grouping\",\"label\":\"hostel\"}",
      other_token,
    ),
  ))
  assert res.status == 403
}

pub fn post_space_invalid_kind_returns_422_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"X\",\"kind\":\"bogus\",\"label\":\"x\"}",
      token,
    ),
  ))
  assert res.status == 422
}

pub fn get_org_spaces_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "GET",
      "/api/organizations/" <> org_id <> "/spaces",
      "",
      token,
    ),
  ))
  assert res.status == 200
}

pub fn show_unknown_space_returns_404_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, _org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/spaces/nope", "", token),
  ))
  assert res.status == 404
}
