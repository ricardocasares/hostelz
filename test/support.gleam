//// Shared test helpers (not a test module — no `*_test` functions). Builds web
//// requests (with/without a Bearer token) and an authenticated Owner + org
//// directly via the repos, so HTTP tests of protected routes don't need to go
//// through password hashing or the login endpoint.

import app/create_organization
import auth/token
import brioche/sql as db
import conversation.{type JsRequest, type RequestBody}
import db/membership_repo
import db/organization_repo
import db/role_repo
import db/session_repo
import db/user_repo
import domain/email
import domain/organization
import domain/user
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/javascript/promise.{type Promise}
import glanoid
import router/context

@external(javascript, "./request_ffi.mjs", "request")
fn js_request(method: String, url: String, body: String) -> JsRequest

@external(javascript, "./request_ffi.mjs", "authedRequest")
fn js_authed_request(
  method: String,
  url: String,
  body: String,
  token: String,
) -> JsRequest

pub fn test_deps() -> context.Deps {
  let assert Ok(conn) = db.connect(db.default_config() |> db.max(1))
  let assert Ok(nanoid) = glanoid.make_generator(glanoid.default_alphabet)
  context.Deps(db: conn, generate_id: fn() { nanoid(21) })
}

pub fn req(method: String, path: String, body: String) -> Request(RequestBody) {
  conversation.to_gleam_request(js_request(method, "http://test" <> path, body))
}

pub fn authed(
  method: String,
  path: String,
  body: String,
  token: String,
) -> Request(RequestBody) {
  conversation.to_gleam_request(js_authed_request(
    method,
    "http://test" <> path,
    body,
    token,
  ))
}

pub fn truncate(conn: db.Connection) -> Promise(Nil) {
  use _ <- promise.map(
    db.query(
      "truncate table memberships, role_permissions, roles, sessions, user_credentials, spaces, guests, organizations, users cascade",
    )
    |> db.returning(decode.dynamic)
    |> db.execute(conn),
  )
  Nil
}

/// Create a user + active session + an organization they own. Returns the raw
/// Bearer token and the org id string. Run after `truncate`.
pub fn owner_setup(deps: context.Deps) -> Promise(#(String, String)) {
  let assert Ok(uid) = user.new_id(deps.generate_id())
  let assert Ok(addr) = email.new("owner@example.com")
  let assert Ok(u) = user.new(uid, addr, "Owner")
  use saved <- promise.await(user_repo.new(deps.db).save(u))
  let assert Ok(_) = saved

  let raw_token = deps.generate_id()
  use session_saved <- promise.await(session_repo.new(deps.db).save(
    token.hash(raw_token),
    uid,
  ))
  let assert Ok(_) = session_saved

  use created <- promise.await(create_organization.run(
    organization_repo.new(deps.db),
    role_repo.new(deps.db),
    membership_repo.new(deps.db),
    deps.generate_id,
    uid,
    "acme",
    "Acme",
  ))
  let assert Ok(org) = created
  promise.resolve(#(
    raw_token,
    organization.organization_id(organization.id(org)),
  ))
}

/// Create an extra user with an active session: returns #(token, user_id).
pub fn user_with_session(
  deps: context.Deps,
  email_str: String,
) -> Promise(#(String, String)) {
  let assert Ok(uid) = user.new_id(deps.generate_id())
  let assert Ok(addr) = email.new(email_str)
  let assert Ok(u) = user.new(uid, addr, "Member")
  use saved <- promise.await(user_repo.new(deps.db).save(u))
  let assert Ok(_) = saved
  let raw_token = deps.generate_id()
  use session_saved <- promise.map(session_repo.new(deps.db).save(
    token.hash(raw_token),
    uid,
  ))
  let assert Ok(_) = session_saved
  #(raw_token, user.user_id(uid))
}
