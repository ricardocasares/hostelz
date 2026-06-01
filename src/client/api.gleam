//// HTTP effects against the backend API, returned as `lustre/effect` values.
////
//// URLs are absolute against the page origin (`storage.origin() <> "/api"`) so
//// requests stay same-origin: proxied to the API server in dev, same host in
//// prod. Authenticated calls carry `Authorization: Bearer <token>`.

import client/decode as dec
import client/storage
import domain/organization.{type Organization}
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http.{type Method, Get, Post}
import gleam/http/request.{type Request}
import gleam/json
import gleam/result
import lustre/effect.{type Effect}
import rsvp

pub type ApiError {
  Network
  Unauthorized
  /// A 4xx the server explained in its `{"error": ...}` body (e.g. "email
  /// already registered", "password must be at least 8 characters").
  Rejected(String)
  ServerError(Int)
  BadResponse
}

fn base() -> String {
  storage.origin() <> "/api"
}

fn map_error(error: rsvp.Error(String)) -> ApiError {
  case error {
    rsvp.NetworkError -> Network
    rsvp.HttpError(response) ->
      case response.status {
        401 -> Unauthorized
        status ->
          case error_message(response.body) {
            Ok(message) -> Rejected(message)
            Error(_) -> ServerError(status)
          }
      }
    _ -> BadResponse
  }
}

/// Pull the human-readable message out of an `{"error": "..."}` body.
fn error_message(body: String) -> Result(String, Nil) {
  json.parse(body, {
    use message <- decode.field("error", decode.string)
    decode.success(message)
  })
  |> result.replace_error(Nil)
}

fn authed(
  token: String,
  method: Method,
  path: String,
) -> Result(Request(String), Nil) {
  use request <- result.try(request.to(base() <> path))
  Ok(
    request
    |> request.set_method(method)
    |> request.set_header("authorization", "Bearer " <> token),
  )
}

/// `POST /auth/login` — returns `#(token, user)` on success.
pub fn login(
  email: String,
  password: String,
  to_msg: fn(Result(#(String, User), ApiError)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])
  let handler =
    rsvp.expect_json(dec.session_decoder(), fn(result) {
      to_msg(case result {
        Error(error) -> Error(map_error(error))
        Ok(#(token, raw)) ->
          case dec.to_user(raw) {
            Ok(user) -> Ok(#(token, user))
            Error(_) -> Error(BadResponse)
          }
      })
    })
  rsvp.post(base() <> "/auth/login", body, handler)
}

/// `POST /auth/register` — creates an account, returning the new user. Does not
/// log in (no token); callers typically follow with `login`.
pub fn register(
  name: String,
  email: String,
  password: String,
  to_msg: fn(Result(User, ApiError)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("email", json.string(email)),
      #("name", json.string(name)),
      #("password", json.string(password)),
    ])
  let handler =
    rsvp.expect_json(dec.user_decoder(), fn(result) {
      to_msg(convert(result, dec.to_user))
    })
  rsvp.post(base() <> "/auth/register", body, handler)
}

/// `GET /auth/me` — resolves the bearer token to the current user.
pub fn me(
  token: String,
  to_msg: fn(Result(User, ApiError)) -> msg,
) -> Effect(msg) {
  let handler =
    rsvp.expect_json(dec.user_decoder(), fn(result) {
      to_msg(convert(result, dec.to_user))
    })
  send(authed(token, Get, "/auth/me"), handler)
}

/// `GET /organizations` — the caller's organizations.
pub fn list_organizations(
  token: String,
  to_msg: fn(Result(List(Organization), ApiError)) -> msg,
) -> Effect(msg) {
  let handler =
    rsvp.expect_json(dec.orgs_decoder(), fn(result) {
      to_msg(convert(result, dec.to_orgs))
    })
  send(authed(token, Get, "/organizations"), handler)
}

/// `POST /auth/logout` — revokes the presented token.
pub fn logout(
  token: String,
  to_msg: fn(Result(Nil, ApiError)) -> msg,
) -> Effect(msg) {
  let handler =
    rsvp.expect_json(decode.success(Nil), fn(result) {
      to_msg(case result {
        Ok(_) -> Ok(Nil)
        Error(error) -> Error(map_error(error))
      })
    })
  send(authed(token, Post, "/auth/logout"), handler)
}

/// Convert a raw decode result through a smart constructor, folding both the
/// transport error and a conversion failure into `ApiError`.
fn convert(
  result: Result(raw, rsvp.Error(String)),
  to_domain: fn(raw) -> Result(a, Nil),
) -> Result(a, ApiError) {
  case result {
    Error(error) -> Error(map_error(error))
    Ok(raw) -> to_domain(raw) |> result.replace_error(BadResponse)
  }
}

fn send(
  request: Result(Request(String), Nil),
  handler: rsvp.Handler(String, msg),
) -> Effect(msg) {
  case request {
    Ok(request) -> rsvp.send(request, handler)
    Error(_) -> effect.none()
  }
}
