//// `POST /guests` — register a guest from a JSON body `{"name","email"}`. The
//// id is minted server-side (see `router/context`), so clients don't supply it.
////
//// The HTTP boundary is pure translation: decode the input, call the
//// `register_guest` use case, then map its result onto a status code. Each
//// use-case error variant has a home — domain validation failures are the
//// client's fault (422) and say which rule broke; a repository failure is ours
//// (500) and stays opaque. The domain and use case know nothing about HTTP.

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

pub fn handle(
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
