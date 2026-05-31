//// The guests HTTP handlers — pure translation between the wire and the
//// `register_guest` / `list_organization_guests` / `find_guest` use cases.
////
//// Guests are nested under their organization:
////   `POST /organizations/:org_id/guests` (`create`) registers a guest from a
////   JSON body `{"name","email"}` plus an optional `"user_id"` linking the
////   guest to a system account; omit it for a walk-in. The org is resolved
////   first (404 if unknown), and a supplied user is resolved too (404 if
////   unknown). `GET /organizations/:org_id/guests` (`list_for_org`) lists that
////   org's guests. `GET /guests/:id` (`show`) returns a single guest globally.
////
//// Domain validation failures are the client's fault (422); a missing org/user
//// is 404; a repository failure is ours (500) and stays opaque.

import app/find_guest
import app/find_organization
import app/find_user
import app/list_organization_guests
import app/register_guest.{
  type RegisterGuestError, InvalidEmail, InvalidGuest, RepoFailed,
}
import conversation.{type RequestBody, type ResponseBody}
import db/guest_repo
import db/organization_repo
import db/user_repo
import domain/email
import domain/guest.{type Guest}
import domain/organization.{type OrganizationId}
import domain/user.{type UserId}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/option.{type Option, None, Some}
import router/context.{type Deps}
import router/reply

/// The shape we accept in the request body. `user_id` is optional — absent (or
/// null) means a walk-in guest with no linked account.
type NewGuest {
  NewGuest(name: String, email: String, user_id: Option(String))
}

/// `GET /organizations/:org_id/guests` — the org's guests, newest first.
pub fn list_for_org(
  deps: Deps,
  org_id: String,
) -> Promise(Response(ResponseBody)) {
  case organization.new_id(org_id) {
    Error(reason) ->
      promise.resolve(reply.json_response(
        422,
        error_json(organization_error_message(reason)),
      ))
    Ok(oid) -> {
      let repo = guest_repo.new(deps.db)
      use result <- promise.map(list_organization_guests.run(repo, oid))
      case result {
        Ok(guests) ->
          reply.json_response(200, json.array(guests, guest_to_json))
        Error(list_organization_guests.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not list guests"))
      }
    }
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

/// `POST /organizations/:org_id/guests` — register a guest under an org.
pub fn create(
  deps: Deps,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  // Resolve the org first: this validates the id and confirms it exists, so an
  // unknown org is a clean 404 rather than a foreign-key 500 at save time.
  let org_repo = organization_repo.new(deps.db)
  use org_result <- promise.await(find_organization.run(org_repo, org_id))
  case org_result {
    Error(find_organization.InvalidId(reason)) ->
      promise.resolve(reply.json_response(
        422,
        error_json(organization_error_message(reason)),
      ))
    Error(find_organization.NotFound) ->
      promise.resolve(reply.json_response(
        404,
        error_json("organization not found"),
      ))
    Error(find_organization.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load organization"),
      ))
    Ok(org) -> create_under_org(deps, organization.id(org), req)
  }
}

fn create_under_org(
  deps: Deps,
  org_id: OrganizationId,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, new_guest_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"name\" and \"email\" strings"),
          ))
        Ok(input) -> resolve_user_and_register(deps, org_id, input)
      }
  }
}

fn resolve_user_and_register(
  deps: Deps,
  org_id: OrganizationId,
  input: NewGuest,
) -> Promise(Response(ResponseBody)) {
  case input.user_id {
    None -> register(deps, org_id, None, input)
    Some(raw_user_id) -> {
      let repo = user_repo.new(deps.db)
      use user_result <- promise.await(find_user.run(repo, raw_user_id))
      case user_result {
        Error(find_user.InvalidId(reason)) ->
          promise.resolve(reply.json_response(
            422,
            error_json(user_error_message(reason)),
          ))
        Error(find_user.NotFound) ->
          promise.resolve(reply.json_response(404, error_json("user not found")))
        Error(find_user.RepoFailed(_)) ->
          promise.resolve(reply.json_response(
            500,
            error_json("could not load user"),
          ))
        Ok(u) -> register(deps, org_id, Some(user.id(u)), input)
      }
    }
  }
}

fn register(
  deps: Deps,
  org_id: OrganizationId,
  user_id: Option(UserId),
  input: NewGuest,
) -> Promise(Response(ResponseBody)) {
  let repo = guest_repo.new(deps.db)
  use result <- promise.map(register_guest.run(
    repo,
    deps.generate_id,
    org_id,
    user_id,
    input.name,
    input.email,
  ))
  case result {
    Ok(saved) -> reply.json_response(201, guest_to_json(saved))
    Error(error) -> error_response(error)
  }
}

fn new_guest_decoder() -> decode.Decoder(NewGuest) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use user_id <- decode.optional_field(
    "user_id",
    None,
    decode.optional(decode.string),
  )
  decode.success(NewGuest(name:, email:, user_id:))
}

fn guest_to_json(g: Guest) -> json.Json {
  json.object([
    #("id", json.string(guest.guest_id(guest.id(g)))),
    #(
      "organization_id",
      json.string(organization.organization_id(guest.organization_id(g))),
    ),
    #(
      "user_id",
      json.nullable(guest.user_id(g), fn(uid) { json.string(user.user_id(uid)) }),
    ),
    #("name", json.string(guest.name(g))),
    #("email", json.string(email.to_string(guest.email(g)))),
  ])
}

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

fn organization_error_message(error: organization.OrganizationError) -> String {
  case error {
    organization.EmptyId -> "organization id must not be empty"
    organization.EmptyName -> "organization name must not be empty"
  }
}

fn user_error_message(error: user.UserError) -> String {
  case error {
    user.EmptyId -> "user id must not be empty"
    user.EmptyName -> "user name must not be empty"
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
