//// The users HTTP handlers — pure translation between the wire and the
//// `register_user` / `list_users` / `find_user` use cases.
////
//// `POST /users` (`create`) registers an account from `{"email","name"}`; the
//// id is minted server-side. `GET /users` (`list`) returns every user;
//// `GET /users/:id` (`show`) returns one or 404. A taken email is a conflict
//// (409); validation failures are 422; repository failures are 500.

import app/find_user
import app/list_users
import app/register_user.{
  type RegisterUserError, EmailTaken, InvalidEmail, InvalidUser, RepoFailed,
}
import conversation.{type RequestBody, type ResponseBody}
import db/user_repo
import domain/email
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/reply

/// The shape we accept in the request body.
type NewUser {
  NewUser(email: String, name: String)
}

/// `GET /users` — every user as a JSON array, newest first.
pub fn list(deps: Deps) -> Promise(Response(ResponseBody)) {
  let repo = user_repo.new(deps.db)
  use result <- promise.map(list_users.run(repo))
  case result {
    Ok(users) -> reply.json_response(200, json.array(users, user_to_json))
    Error(list_users.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list users"))
  }
}

/// `GET /users/:id` — a single user by id, or 404.
pub fn show(deps: Deps, id: String) -> Promise(Response(ResponseBody)) {
  let repo = user_repo.new(deps.db)
  use result <- promise.map(find_user.run(repo, id))
  case result {
    Ok(u) -> reply.json_response(200, user_to_json(u))
    Error(find_user.InvalidId(reason)) ->
      reply.json_response(422, error_json(user_error_message(reason)))
    Error(find_user.NotFound) ->
      reply.json_response(404, error_json("user not found"))
    Error(find_user.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not load user"))
  }
}

/// `POST /users` — register an account from a JSON body `{"email","name"}`.
pub fn create(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, new_user_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"email\" and \"name\" strings"),
          ))
        Ok(input) -> {
          let repo = user_repo.new(deps.db)
          use result <- promise.map(register_user.run(
            repo,
            deps.generate_id,
            input.email,
            input.name,
          ))
          case result {
            Ok(saved) -> reply.json_response(201, user_to_json(saved))
            Error(error) -> error_response(error)
          }
        }
      }
  }
}

fn new_user_decoder() -> decode.Decoder(NewUser) {
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(NewUser(email:, name:))
}

fn user_to_json(u: User) -> json.Json {
  json.object([
    #("id", json.string(user.user_id(user.id(u)))),
    #("email", json.string(email.to_string(user.email(u)))),
    #("name", json.string(user.name(u))),
  ])
}

fn error_response(error: RegisterUserError) -> Response(ResponseBody) {
  case error {
    InvalidUser(reason) ->
      reply.json_response(422, error_json(user_error_message(reason)))
    InvalidEmail(reason) ->
      reply.json_response(422, error_json(email_error_message(reason)))
    EmailTaken -> reply.json_response(409, error_json("email already registered"))
    RepoFailed(_) ->
      reply.json_response(500, error_json("could not save user"))
  }
}

fn user_error_message(error: user.UserError) -> String {
  case error {
    user.EmptyId -> "id must not be empty"
    user.EmptyName -> "name must not be empty"
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
