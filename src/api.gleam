//// A Vercel Function written in Gleam, compiled to JavaScript and served by
//// Vercel's Bun runtime.
////
//// This module is just the glue between Vercel and the app: `conversation`
//// gives us bindings to the web-standard `Request`/`Response` objects, so the
//// only JavaScript we need is the tiny adapter in `src/api.ts`, which calls our
//// `main` factory once at module load and re-exports the handler it returns as
//// `export default { fetch: main() }`. Everything else — routing, middleware,
//// handlers — lives under `src/router`.

import conversation.{type JsRequest, type JsResponse}
import gleam/javascript/promise.{type Promise}
import router
import router/context

/// Builds the shared `Deps` once, then returns the request handler that closes
/// over them. `src/api.ts` calls this at module load, and the JS module graph is
/// evaluated once per process — so the connection is opened exactly once, the
/// same guarantee the old `once` FFI gave, but without mutable module state.
///
/// The returned handler converts the standard JS `Request` into a Gleam one,
/// runs it through the router (`router.handle`), then converts the Gleam
/// `Response` back. Every route returns a `Promise`, so handlers are free to
/// read the body or `await` a database/`fetch` call. Bun accepts
/// `Promise<Response>`, so the adapter needs no changes.
pub fn main() -> fn(JsRequest) -> Promise(JsResponse) {
  let deps = context.deps()
  fn(req) {
    let req = conversation.to_gleam_request(req)
    use response <- promise.map(router.handle(deps, req))
    conversation.to_js_response(response)
  }
}
