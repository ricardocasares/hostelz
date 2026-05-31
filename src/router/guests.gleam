//// The guests HTTP handlers, gated by `guest:*` permissions. Guests are nested
//// under their organization:
////   `POST /organizations/:org_id/guests` (`create`, `guest:create`) — body
////   `{"name","email"}` plus an optional `"user_id"` (a walk-in omits it; a
////   supplied user is resolved, 404 if unknown). `GET /organizations/:org_id/guests`
////   (`list_for_org`, `guest:read`). `GET /guests/:id` (`show`) resolves the
////   guest then checks `guest:read` on its organization.

import app/find_guest
import app/find_user
import app/list_organization_guests
import app/register_guest.{
  type RegisterGuestError, InvalidEmail, InvalidGuest, RepoFailed,
}
import conversation.{type RequestBody, type ResponseBody}
import db/guest_repo
import db/user_repo
import domain/email
import domain/guest.{type Guest}
import domain/organization.{type OrganizationId}
import domain/permission
import domain/user.{type User, type UserId}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/option.{type Option, None, Some}
import router/context.{type Deps}
import router/guard
import router/reply

type NewGuest {
  NewGuest(name: String, email: String, user_id: Option(String))
}

pub fn list_for_org(
  deps: Deps,
  user: User,
  org_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.GuestRead)
  let repo = guest_repo.new(deps.db)
  use result <- promise.map(list_organization_guests.run(repo, oid))
  case result {
    Ok(guests) -> reply.json_response(200, json.array(guests, guest_to_json))
    Error(list_organization_guests.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list guests"))
  }
}

pub fn show(
  deps: Deps,
  user: User,
  id: String,
) -> Promise(Response(ResponseBody)) {
  let repo = guest_repo.new(deps.db)
  use result <- promise.await(find_guest.run(repo, id))
  case result {
    Error(find_guest.NotFound) | Error(find_guest.InvalidId(_)) ->
      promise.resolve(reply.json_response(404, error_json("guest not found")))
    Error(find_guest.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load guest"),
      ))
    Ok(g) -> {
      use <- guard.require_permission_for_org(
        deps,
        user,
        guest.organization_id(g),
        permission.GuestRead,
      )
      promise.resolve(reply.json_response(200, guest_to_json(g)))
    }
  }
}

pub fn create(
  deps: Deps,
  user: User,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(
    deps,
    user,
    org_id,
    permission.GuestCreate,
  )
  create_under_org(deps, oid, req)
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
