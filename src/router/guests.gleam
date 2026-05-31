//// The guests HTTP handlers — pure translation between the wire and the
//// `register_guest` / `list_guests` / `find_guest` use cases.
////
//// `POST /guests` (`create`) registers a guest from a JSON body
//// `{"name","email"}`; the id is minted server-side (see `router/context`), so
//// clients don't supply it. `GET /guests` (`list`) returns every guest as a
//// JSON array, newest first. `GET /guests/:id` (`show`) returns a single guest,
//// or 404 if none exists.
////
//// Each use-case error variant has a home — domain validation failures are the
//// client's fault (422) and say which rule broke; a repository failure is ours
//// (500) and stays opaque. The domain and use cases know nothing about HTTP.

import app/find_guest
import app/list_guests
import app/register_guest.{
  type RegisterGuestError, InvalidEmail, InvalidGuest, RepoFailed,
}
import conversation.{type RequestBody, type ResponseBody}
import db/guest_repo
import domain/email
import domain/guest.{type Guest}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/reply

/// The shape we accept in the request body.
type NewGuest {
  NewGuest(name: String, email: String)
}

/// `GET /guests` — every guest as a JSON array, newest first.
pub fn list(deps: Deps) -> Promise(Response(ResponseBody)) {
  let repo = guest_repo.new(deps.db)
  use result <- promise.map(list_guests.run(repo))
  case result {
    Ok(guests) -> reply.json_response(200, json.array(guests, guest_to_json))
    Error(list_guests.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list guests"))
  }
}

/// `GET /guests/:id` — a single guest by id, or 404 if none exists.
pub fn show(deps: Deps, id: String) -> Promise(Response(ResponseBody)) {
  let repo = guest_repo.new(deps.db)
  use result <- promise.map(find_guest.run(repo, id))
  case result {
    Ok(g) -> reply.json_response(200, guest_to_json(g))
    Error(find_guest.InvalidId(reason)) ->
      reply.json_response(422, error_json(guest_error_message(reason)))
    Error(find_guest.NotFound) ->
      reply.json_response(404, error_json("guest not found"))
    Error(find_guest.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not load guest"))
  }
}

/// `POST /guests` — register a guest from a JSON body `{"name","email"}`.
pub fn create(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    // Body missing or not valid JSON.
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, new_guest_decoder()) {
        // Valid JSON, wrong shape.
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"name\" and \"email\" strings"),
          ))
        Ok(input) -> {
          let repo = guest_repo.new(deps.db)
          use result <- promise.map(register_guest.run(
            repo,
            deps.generate_id,
            input.name,
            input.email,
          ))
          case result {
            Ok(saved) -> reply.json_response(201, guest_to_json(saved))
            Error(error) -> error_response(error)
          }
        }
      }
  }
}

fn new_guest_decoder() -> decode.Decoder(NewGuest) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(NewGuest(name:, email:))
}

fn guest_to_json(g: Guest) -> json.Json {
  json.object([
    #("id", json.string(guest.guest_id(guest.id(g)))),
    #("name", json.string(guest.name(g))),
    #("email", json.string(email.to_string(guest.email(g)))),
  ])
}

/// Translate a use-case error into a response. Validation problems are the
/// client's fault (422) and report which rule failed; a repository failure is
/// ours (500) and stays opaque to the client.
fn error_response(error: RegisterGuestError) -> Response(ResponseBody) {
  case error {
    InvalidGuest(reason) ->
      reply.json_response(422, error_json(guest_error_message(reason)))
    InvalidEmail(reason) ->
      reply.json_response(422, error_json(email_error_message(reason)))
    RepoFailed(_) ->
      reply.json_response(500, error_json("could not save guest"))
  }
}

fn guest_error_message(error: guest.GuestError) -> String {
  case error {
    guest.EmptyId -> "id must not be empty"
    guest.EmptyName -> "name must not be empty"
  }
}

fn email_error_message(error: email.EmailError) -> String {
  case error {
    email.Empty -> "email must not be empty"
    email.MissingAt -> "email must contain an @"
    email.TooManyAt -> "email must contain exactly one @"
    email.MissingTextBeforeAt -> "email must have text before the @"
    email.MissingTextAfterAt -> "email must have text after the @"
  }
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
