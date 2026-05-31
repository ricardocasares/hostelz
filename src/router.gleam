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
import gleam/javascript/promise.{type Promise}
import log
import router/auth
import router/bookings
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
  // Correlate every log line for this request; honour an inbound id for tracing.
  let request_id = case request.get_header(req, "x-request-id") {
    Ok(id) -> id
    Error(Nil) -> deps.generate_id()
  }
  // Rebind the process-wide logger with this request's context, so handlers log
  // with request_id/method/path for free via `deps.logger`.
  let deps =
    context.Deps(
      ..deps,
      logger: log.with(deps.logger, [
        log.string("request_id", request_id),
        log.string("method", http.method_to_string(req.method)),
        log.string("path", req.path),
      ]),
    )

  use <- log_request(deps.logger)
  use <- set_request_id(request_id)
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

    Get, ["organizations", oid, "bookings"] -> bookings.list(deps, user, oid)
    Post, ["organizations", oid, "bookings"] ->
      bookings.create(deps, user, oid, req)
    Get, ["organizations", oid, "room-types", "available"] ->
      bookings.available_room_types(deps, user, oid, req)
    Get, ["organizations", oid, "room-types", sid, "availability"] ->
      bookings.room_type_availability(deps, user, oid, sid, req)

    Get, ["guests", id] -> guests.show(deps, user, id)
    Get, ["spaces", id] -> spaces.show(deps, user, id)
    Get, ["spaces", id, "children"] -> spaces.list_children(deps, user, id)
    Put, ["spaces", id, "parent"] -> spaces.reparent(deps, user, id, req)
    Put, ["spaces", id, "bookable"] -> spaces.set_bookable(deps, user, id, req)

    Get, ["bookings", id] -> bookings.show(deps, user, id)
    Put, ["bookings", id, "status"] -> bookings.transition(deps, user, id, req)
    Put, ["bookings", id, "items", item, "assignment"] ->
      bookings.assign(deps, user, id, item, req)

    _, _ -> promise.resolve(reply.text(405, "Method not allowed"))
  }
}

// --- Middleware ------------------------------------------------------------

/// Logs the request before the handler runs, and the response (with status)
/// after. `logger` already carries request_id/method/path.
fn log_request(
  logger: log.Logger,
  handler: fn() -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  log.info(logger, "request received")
  use res <- promise.map(handler())
  log.info(
    log.with(logger, [log.int("status", res.status)]),
    "request completed",
  )
  res
}

/// Echoes the request id back so clients/traces can correlate.
fn set_request_id(
  request_id: String,
  handler: fn() -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  use res <- promise.map(handler())
  response.set_header(res, "x-request-id", request_id)
}

/// Adds a header to every response once the handler has produced one.
fn default_headers(
  handler: fn() -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  use res <- promise.map(handler())
  response.set_header(res, "x-powered-by", "gleam")
}
