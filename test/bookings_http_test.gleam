//// HTTP tests for the booking routes under authentication. The owner has every
//// permission; a non-member is forbidden. A dorm with one bed (capacity 1)
//// drives the overbooking case.

import conversation.{Text}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/string
import router
import router/context
import support

fn id_of(body: String) -> String {
  let assert Ok(id) =
    json.parse(body, {
      use id <- decode.field("id", decode.string)
      decode.success(id)
    })
  id
}

/// Create a dorm grouping with a single bed (capacity 1); returns the dorm id.
fn dorm_with_bed(
  deps: context.Deps,
  token: String,
  org_id: String,
) -> Promise(String) {
  use dorm <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"Dorm\",\"kind\":\"grouping\",\"label\":\"dorm\"}",
      token,
    ),
  ))
  let assert Text(dorm_body) = dorm.body
  let dorm_id = id_of(dorm_body)
  use _bed <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/spaces",
      "{\"name\":\"B1\",\"kind\":\"unit\",\"label\":\"bed\",\"parent_id\":\""
        <> dorm_id
        <> "\"}",
      token,
    ),
  ))
  dorm_id
}

fn book_body(space_id: String) -> String {
  "{\"items\":[{\"kind\":\"unit\",\"space_id\":\""
  <> space_id
  <> "\",\"check_in\":\"2026-06-01\",\"check_out\":\"2026-06-03\"}]}"
}

pub fn post_booking_returns_201_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use dorm_id <- promise.await(dorm_with_bed(deps, token, org_id))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/bookings",
      book_body(dorm_id),
      token,
    ),
  ))
  assert res.status == 201
  let assert Text(body) = res.body
  assert string.contains(body, "\"status\":\"confirmed\"")
}

pub fn overbooking_returns_409_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use dorm_id <- promise.await(dorm_with_bed(deps, token, org_id))
  use first <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/bookings",
      book_body(dorm_id),
      token,
    ),
  ))
  assert first.status == 201
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/bookings",
      book_body(dorm_id),
      token,
    ),
  ))
  assert res.status == 409
}

pub fn booking_unauthenticated_returns_401_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(_token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.req(
      "POST",
      "/api/organizations/" <> org_id <> "/bookings",
      book_body("sp_x"),
    ),
  ))
  assert res.status == 401
}

pub fn booking_non_member_returns_403_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(owner, org_id) <- promise.await(support.owner_setup(deps))
  use dorm_id <- promise.await(dorm_with_bed(deps, owner, org_id))
  use #(other, _uid) <- promise.await(support.user_with_session(
    deps,
    "outsider@example.com",
  ))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/bookings",
      book_body(dorm_id),
      other,
    ),
  ))
  assert res.status == 403
}

pub fn list_bookings_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "GET",
      "/api/organizations/" <> org_id <> "/bookings",
      "",
      token,
    ),
  ))
  assert res.status == 200
}

pub fn availability_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use dorm_id <- promise.await(dorm_with_bed(deps, token, org_id))
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "GET",
      "/api/organizations/"
        <> org_id
        <> "/room-types/"
        <> dorm_id
        <> "/availability?from=2026-06-01&to=2026-06-03",
      "",
      token,
    ),
  ))
  assert res.status == 200
  let assert Text(body) = res.body
  assert string.contains(body, "\"beds_left\":1")
}

pub fn transition_cancel_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use #(token, org_id) <- promise.await(support.owner_setup(deps))
  use dorm_id <- promise.await(dorm_with_bed(deps, token, org_id))
  use created <- promise.await(router.handle(
    deps,
    support.authed(
      "POST",
      "/api/organizations/" <> org_id <> "/bookings",
      book_body(dorm_id),
      token,
    ),
  ))
  let assert Text(created_body) = created.body
  let booking_id = id_of(created_body)
  use res <- promise.map(router.handle(
    deps,
    support.authed(
      "PUT",
      "/api/bookings/" <> booking_id <> "/status",
      "{\"status\":\"cancelled\"}",
      token,
    ),
  ))
  assert res.status == 200
  let assert Text(body) = res.body
  assert string.contains(body, "\"status\":\"cancelled\"")
}
