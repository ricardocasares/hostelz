//// The middleware stack and route dispatch. `api.main` adapts the JS
//// `Request`/`Response` and hands every request to `handle`, which is the only
//// thing the entrypoint needs to know about.

import conversation.{type RequestBody, type ResponseBody}
import gleam/http.{Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/javascript/promise.{type Promise}
import router/context.{type Deps}
import router/guests
import router/reply

/// The middleware stack, followed by dispatch. Each `use` wraps everything
/// below it, so the block after the middleware *is* the handler they wrap.
///
/// Handlers receive the whole `Request`, so they can reach the body (which is
/// asynchronous and read-once — see `router/guests`), headers and query.
///
/// `deps` (the db connection, etc.) is built once by `api.main` and threaded in
/// so handlers that touch the database — like `router/guests` — can reach it.
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

  // The guests handlers read the body / await the database, so they return a
  // `Promise` directly; the 405 fallback is synchronous, wrapped by the single
  // `promise.resolve`.
  case req.method, segments {
    Get, ["guests"] -> guests.list(deps)
    Get, ["guests", id] -> guests.show(deps, id)
    Post, ["guests"] -> guests.create(deps, req)
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
