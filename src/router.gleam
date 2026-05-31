//// The middleware stack and route dispatch. `api.main` adapts the JS
//// `Request`/`Response` and hands every request to `handle`.
////
//// Authentication is a single middleware: `register`/`login` are public, and
//// every other route is wrapped once by `guard.require_auth`, which resolves
//// the Bearer token to the current `User` (401 otherwise) and threads it into
//// the protected handlers. Authorization (per-permission) is enforced inside
//// each protected handler via `guard.require_permission`.

import conversation.{type RequestBody, type ResponseBody}
import domain/user.{type User}
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import router/auth
import router/context.{type Deps}
import router/guard
import router/guests
import router/members
import router/organizations
import router/reply
import router/roles
import router/spaces

pub fn handle(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use <- log_request(req)
  use <- default_headers()

  // Requests arrive under the `/api` prefix, so drop it and route on
  // root-relative paths.
  let segments = case request.path_segments(req) {
    ["api", ..rest] -> rest
    segments -> segments
  }

  case req.method, segments {
    // Public: no session required.
    Post, ["auth", "register"] -> auth.register(deps, req)
    Post, ["auth", "login"] -> auth.login(deps, req)

    // Everything else requires authentication; the user is threaded through.
    _, _ -> {
      use user <- guard.require_auth(deps, req)
      dispatch(deps, user, req, segments)
    }
  }
}

fn dispatch(
  deps: Deps,
  user: User,
  req: Request(RequestBody),
  segments: List(String),
) -> Promise(Response(ResponseBody)) {
  case req.method, segments {
    Post, ["auth", "logout"] -> auth.logout(deps, req)
    Get, ["auth", "me"] -> auth.me(deps, user)

    Get, ["organizations"] -> organizations.list(deps, user)
    Post, ["organizations"] -> organizations.create(deps, user, req)
    Get, ["organizations", id] -> organizations.show(deps, user, id)

    Get, ["organizations", oid, "members"] -> members.list(deps, user, oid)
    Post, ["organizations", oid, "members"] -> members.add(deps, user, oid, req)
    Put, ["organizations", oid, "members", uid] ->
      members.update_role(deps, user, oid, uid, req)
    Delete, ["organizations", oid, "members", uid] ->
      members.remove(deps, user, oid, uid)

    Get, ["organizations", oid, "roles"] -> roles.list(deps, user, oid)
    Post, ["organizations", oid, "roles"] -> roles.create(deps, user, oid, req)
    Put, ["organizations", oid, "roles", rid] ->
      roles.update(deps, user, oid, rid, req)
    Delete, ["organizations", oid, "roles", rid] ->
      roles.delete(deps, user, oid, rid)

    Get, ["organizations", oid, "guests"] ->
      guests.list_for_org(deps, user, oid)
    Post, ["organizations", oid, "guests"] ->
      guests.create(deps, user, oid, req)
    Get, ["organizations", oid, "spaces"] ->
      spaces.list_for_org(deps, user, oid)
    Post, ["organizations", oid, "spaces"] ->
      spaces.create(deps, user, oid, req)

    Get, ["guests", id] -> guests.show(deps, user, id)
    Get, ["spaces", id] -> spaces.show(deps, user, id)
    Get, ["spaces", id, "children"] -> spaces.list_children(deps, user, id)

    _, _ -> promise.resolve(reply.text(405, "Method not allowed"))
  }
}

// --- Middleware ------------------------------------------------------------

/// Logs the method and path before the handler runs, and the status after.
fn log_request(
  req: Request(RequestBody),
  handler: fn() -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  io.println(http.method_to_string(req.method) <> " " <> req.path)
  use res <- promise.map(handler())
  io.println("-> " <> int.to_string(res.status))
  res
}

/// Adds a header to every response once the handler has produced one.
fn default_headers(
  handler: fn() -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  use res <- promise.map(handler())
  response.set_header(res, "x-powered-by", "gleam")
}
