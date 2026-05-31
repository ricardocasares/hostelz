// Test helper: build a standard web `Request` so tests can drive the Gleam HTTP
// handlers. `conversation.RequestBody` is opaque and can't be constructed from
// Gleam, so we make a real `Request` here and hand it to
// `conversation.to_gleam_request`. Bun/Node provide `Request` globally.
export function request(method, url, body) {
  return build(method, url, body, "");
}

// Same, with an `Authorization: Bearer <token>` header for authenticated routes.
export function authedRequest(method, url, body, token) {
  return build(method, url, body, token);
}

function build(method, url, body, token) {
  const init = { method, headers: {} };
  // GET/HEAD can't carry a body; only attach one when there's something to send.
  if (body !== "" && method !== "GET" && method !== "HEAD") {
    init.body = body;
    init.headers["content-type"] = "application/json";
  }
  if (token !== "") {
    init.headers["authorization"] = "Bearer " + token;
  }
  return new Request(url, init);
}
