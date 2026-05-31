//// Authentication HTTP handlers: register, login, logout, me.
////
//// `POST /auth/register` `{email,name,password}` creates an account (201).
//// `POST /auth/login` `{email,password}` returns `{token, user}` (200) — send
//// the token as `Authorization: Bearer <token>`. `POST /auth/logout` revokes
//// the presented token. `GET /auth/me` returns the current user.

import app/login
import app/logout
import app/register_user.{
  type RegisterUserError, EmailTaken, InvalidEmail, InvalidPassword, InvalidUser,
  RepoFailed,
}
import auth/password
import conversation.{type RequestBody, type ResponseBody}
import db/credential_repo
import db/session_repo
import db/user_repo
import domain/email
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/guard
import router/reply

type Registration {
  Registration(email: String, name: String, password: String)
}

type Credentials {
  Credentials(email: String, password: String)
}

pub fn register(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, registration_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"email\", \"name\" and \"password\" strings"),
          ))
        Ok(input) -> {
          let users = user_repo.new(deps.db)
          let credentials = credential_repo.new(deps.db)
          use result <- promise.map(register_user.run(
            users,
            credentials,
            deps.generate_id,
            input.email,
            input.name,
            input.password,
          ))
          case result {
            Ok(saved) -> reply.json_response(201, user_to_json(saved))
            Error(error) -> register_error(error)
          }
        }
      }
  }
}

pub fn login(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, credentials_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"email\" and \"password\" strings"),
          ))
        Ok(input) -> {
          let users = user_repo.new(deps.db)
          let credentials = credential_repo.new(deps.db)
          let sessions = session_repo.new(deps.db)
          use result <- promise.map(login.run(
            users,
            credentials,
            sessions,
            deps.generate_id,
            input.email,
            input.password,
          ))
          case result {
            Ok(#(token, user)) ->
              reply.json_response(200, session_json(token, user))
            Error(login.InvalidCredentials) ->
              reply.json_response(401, error_json("invalid email or password"))
            Error(login.RepoFailed(_)) ->
              reply.json_response(500, error_json("could not log in"))
          }
        }
      }
  }
}

pub fn logout(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  case guard.bearer_token(req) {
    // require_auth already validated the token, so this won't normally happen.
    Error(Nil) -> promise.resolve(reply.json_response(200, ok_json()))
    Ok(token) -> {
      let sessions = session_repo.new(deps.db)
      use result <- promise.map(logout.run(sessions, token))
      case result {
        Ok(Nil) -> reply.json_response(200, ok_json())
        Error(logout.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not log out"))
      }
    }
  }
}

pub fn me(_deps: Deps, user: User) -> Promise(Response(ResponseBody)) {
  promise.resolve(reply.json_response(200, user_to_json(user)))
}

fn registration_decoder() -> decode.Decoder(Registration) {
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(Registration(email:, name:, password:))
}

fn credentials_decoder() -> decode.Decoder(Credentials) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(Credentials(email:, password:))
}

fn user_to_json(u: User) -> json.Json {
  json.object([
    #("id", json.string(user.user_id(user.id(u)))),
    #("email", json.string(email.to_string(user.email(u)))),
    #("name", json.string(user.name(u))),
  ])
}

fn session_json(token: String, user: User) -> json.Json {
  json.object([#("token", json.string(token)), #("user", user_to_json(user))])
}

fn ok_json() -> json.Json {
  json.object([#("ok", json.bool(True))])
}

fn register_error(error: RegisterUserError) -> Response(ResponseBody) {
  case error {
    InvalidUser(_) ->
      reply.json_response(422, error_json("name must not be empty"))
    InvalidEmail(_) ->
      reply.json_response(422, error_json("a valid email is required"))
    InvalidPassword(password.TooShort) ->
      reply.json_response(
        422,
        error_json("password must be at least 8 characters"),
      )
    EmailTaken ->
      reply.json_response(409, error_json("email already registered"))
    RepoFailed(_) -> reply.json_response(500, error_json("could not register"))
  }
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
