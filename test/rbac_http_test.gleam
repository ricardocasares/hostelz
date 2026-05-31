//// End-to-end RBAC test: an Owner creates a custom role with a couple of
//// permissions, adds a user to it, and that member is allowed exactly what the
//// role grants and forbidden everything else. Exercises register, login, role
//// creation, membership, and permission enforcement together.

import conversation.{Text}
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/json
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

fn token_of(body: String) -> String {
  let assert Ok(t) =
    json.parse(body, {
      use t <- decode.field("token", decode.string)
      decode.success(t)
    })
  t
}

pub fn custom_role_grants_exactly_its_permissions_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(owner_token, org_id) <- promise.await(support.owner_setup(deps))

  // a user account for the staff member
  use reg <- promise.await(router.handle(
    deps,
    support.req(
      "POST",
      "/api/auth/register",
      "{\"email\":\"staff@example.com\",\"name\":\"Staff\",\"password\":\"password123\"}",
    ),
  ))
  assert reg.status == 201

  // owner creates a Front Desk role (guests only)
  use role_res <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/roles",
      "{\"name\":\"Front Desk\",\"permissions\":[\"guest:create\",\"guest:read\"]}",
      owner_token,
    ),
  ))
  assert role_res.status == 201
  let assert Text(role_body) = role_res.body
  let role_id = id_of(role_body)

  // owner assigns the staff member that role
  use add_res <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/members",
      "{\"email\":\"staff@example.com\",\"role_id\":\"" <> role_id <> "\"}",
      owner_token,
    ),
  ))
  assert add_res.status == 201

  // staff logs in
  use login <- promise.await(router.handle(
    deps,
    support.req(
      "POST",
      "/api/auth/login",
      "{\"email\":\"staff@example.com\",\"password\":\"password123\"}",
    ),
  ))
  let assert Text(login_body) = login.body
  let staff_token = token_of(login_body)

  // allowed: create a guest
  use guest_res <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/guests",
      "{\"name\":\"Jo\",\"email\":\"jo@example.com\"}",
      staff_token,
    ),
  ))
  assert guest_res.status == 201

  // forbidden: create a space (no space:create)
  use space_res <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Main\",\"kind\":\"grouping\",\"label\":\"hostel\"}",
      staff_token,
    ),
  ))
  assert space_res.status == 403

  // forbidden: create a role (no role:create)
  use role2_res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/roles",
      "{\"name\":\"X\",\"permissions\":[]}",
      staff_token,
    ),
  ))
  assert role2_res.status == 403
}
