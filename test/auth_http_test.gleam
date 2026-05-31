//// HTTP tests for the authentication routes: register, login, me. These run
//// real argon2 hashing/verification via Bun.

import conversation.{Text}
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/json
import gleam/string
import router
import support

fn token_of(body: String) -> String {
  let assert Ok(t) =
    json.parse(body, {
      use t <- decode.field("token", decode.string)
      decode.success(t)
    })
  t
}

fn register(deps, email_str, password) {
  router.handle(
    deps,
    support.req(
      "POST",
      "/api/auth/register",
      "{\"email\":\""
        <> email_str
        <> "\",\"name\":\"Ada\",\"password\":\""
        <> password
        <> "\"}",
    ),
  )
}

pub fn register_returns_201_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use res <- promise.map(register(deps, "ada@example.com", "password123"))
  assert res.status == 201
}

pub fn register_short_password_returns_422_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use res <- promise.map(register(deps, "ada@example.com", "short"))
  assert res.status == 422
}

pub fn register_duplicate_email_returns_409_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use first <- promise.await(register(deps, "ada@example.com", "password123"))
  assert first.status == 201
  use second <- promise.map(register(deps, "ada@example.com", "password123"))
  assert second.status == 409
}

pub fn login_returns_a_token_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use _ <- promise.await(register(deps, "ada@example.com", "password123"))
  use res <- promise.map(router.handle(
    deps,
    support.req(
      "POST",
      "/api/auth/login",
      "{\"email\":\"ada@example.com\",\"password\":\"password123\"}",
    ),
  ))
  assert res.status == 200
  let assert Text(body) = res.body
  assert string.contains(body, "\"token\":")
}

pub fn login_wrong_password_returns_401_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use _ <- promise.await(register(deps, "ada@example.com", "password123"))
  use res <- promise.map(router.handle(
    deps,
    support.req(
      "POST",
      "/api/auth/login",
      "{\"email\":\"ada@example.com\",\"password\":\"wrong-password\"}",
    ),
  ))
  assert res.status == 401
}

pub fn me_without_token_returns_401_test() {
  let deps = support.test_deps()
  use res <- promise.map(router.handle(deps, support.req("GET", "/api/auth/me", "")))
  assert res.status == 401
}

pub fn me_with_token_returns_200_test() {
  let deps = support.test_deps()
  use _ <- promise.await(support.truncate(deps.db))
  use _ <- promise.await(register(deps, "ada@example.com", "password123"))
  use login <- promise.await(router.handle(
    deps,
    support.req(
      "POST",
      "/api/auth/login",
      "{\"email\":\"ada@example.com\",\"password\":\"password123\"}",
    ),
  ))
  let assert Text(login_body) = login.body
  let token = token_of(login_body)
  use res <- promise.map(router.handle(
    deps,
    support.authed("GET", "/api/auth/me", "", token),
  ))
  assert res.status == 200
  let assert Text(body) = res.body
  assert string.contains(body, "\"email\":\"ada@example.com\"")
}
