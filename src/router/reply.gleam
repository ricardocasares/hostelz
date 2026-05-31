//// Small helpers for building the responses handlers return, shared by the
//// router (for its 404/405 fallbacks) and every handler module. Named `reply`
//// so it doesn't clash with `gleam/http/response`.

import conversation.{type ResponseBody, Text}
import gleam/http/response.{type Response}
import gleam/json

/// A `text/plain` response with the given status and body.
pub fn text(status: Int, body: String) -> Response(ResponseBody) {
  response.new(status)
  |> response.set_header("content-type", "text/plain; charset=utf-8")
  |> response.set_body(Text(body))
}

/// An `application/json` response, serialising the given JSON value.
pub fn json_response(status: Int, body: json.Json) -> Response(ResponseBody) {
  response.new(status)
  |> response.set_header("content-type", "application/json")
  |> response.set_body(Text(json.to_string(body)))
}
