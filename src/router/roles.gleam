//// Role-management HTTP handlers (Owner, or any role with the matching role:*
//// permission). Permissions in the body are catalog strings like "space:create".

import app/create_role
import app/delete_role
import app/list_roles
import app/update_role
import conversation.{type RequestBody, type ResponseBody}
import db/role_repo
import domain/permission.{type Permission}
import domain/role.{type Role}
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/result
import router/context.{type Deps}
import router/guard
import router/reply

type RoleInput {
  RoleInput(name: String, permissions: List(String))
}

pub fn list(
  deps: Deps,
  user: User,
  org_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.RoleRead)
  let repo = role_repo.new(deps.db)
  use result <- promise.map(list_roles.run(repo, oid))
  case result {
    Ok(roles) -> reply.json_response(200, json.array(roles, role_to_json))
    Error(list_roles.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list roles"))
  }
}

pub fn create(
  deps: Deps,
  user: User,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.RoleCreate)
  use input <- with_role_input(req)
  case input {
    Error(response) -> promise.resolve(response)
    Ok(#(name, permissions)) -> {
      let repo = role_repo.new(deps.db)
      use result <- promise.map(create_role.run(
        repo,
        deps.generate_id,
        oid,
        name,
        permissions,
      ))
      case result {
        Ok(role) -> reply.json_response(201, role_to_json(role))
        Error(create_role.InvalidRole(_)) ->
          reply.json_response(422, error_json("role name must not be empty"))
        Error(create_role.NameTaken) ->
          reply.json_response(409, error_json("role name already used"))
        Error(create_role.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not create role"))
      }
    }
  }
}

pub fn update(
  deps: Deps,
  user: User,
  org_id: String,
  role_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.RoleUpdate)
  use input <- with_role_input(req)
  case input {
    Error(response) -> promise.resolve(response)
    Ok(#(name, permissions)) -> {
      let repo = role_repo.new(deps.db)
      use result <- promise.map(update_role.run(
        repo,
        oid,
        role_id,
        name,
        permissions,
      ))
      case result {
        Ok(role) -> reply.json_response(200, role_to_json(role))
        Error(update_role.NotFound) | Error(update_role.InvalidId(_)) ->
          reply.json_response(404, error_json("role not found"))
        Error(update_role.CannotEditOwner) ->
          reply.json_response(
            403,
            error_json("the owner role cannot be edited"),
          )
        Error(update_role.InvalidName(_)) ->
          reply.json_response(422, error_json("role name must not be empty"))
        Error(update_role.NameTaken) ->
          reply.json_response(409, error_json("role name already used"))
        Error(update_role.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not update role"))
      }
    }
  }
}

pub fn delete(
  deps: Deps,
  user: User,
  org_id: String,
  role_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.RoleDelete)
  let repo = role_repo.new(deps.db)
  use result <- promise.map(delete_role.run(repo, oid, role_id))
  case result {
    Ok(Nil) -> reply.json_response(200, ok_json())
    Error(delete_role.NotFound) | Error(delete_role.InvalidId(_)) ->
      reply.json_response(404, error_json("role not found"))
    Error(delete_role.CannotDeleteOwner) ->
      reply.json_response(403, error_json("the owner role cannot be deleted"))
    Error(delete_role.RoleInUse) ->
      reply.json_response(409, error_json("role is still assigned to a member"))
    Error(delete_role.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not delete role"))
  }
}

/// Read + validate the `{name, permissions}` body, parsing each permission
/// string against the catalog. The continuation receives a ready response on
/// failure, or the parsed inputs on success.
fn with_role_input(
  req: Request(RequestBody),
  next: fn(Result(#(String, List(Permission)), Response(ResponseBody))) ->
    Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      next(Error(reply.json_response(400, error_json("invalid JSON"))))
    Ok(data) ->
      case decode.run(data, role_input_decoder()) {
        Error(_) ->
          next(
            Error(reply.json_response(
              422,
              error_json("expected \"name\" and \"permissions\""),
            )),
          )
        Ok(input) ->
          case parse_permissions(input.permissions) {
            Error(message) ->
              next(Error(reply.json_response(422, error_json(message))))
            Ok(permissions) -> next(Ok(#(input.name, permissions)))
          }
      }
  }
}

fn role_input_decoder() -> decode.Decoder(RoleInput) {
  use name <- decode.field("name", decode.string)
  use permissions <- decode.field("permissions", decode.list(decode.string))
  decode.success(RoleInput(name:, permissions:))
}

fn parse_permissions(raw: List(String)) -> Result(List(Permission), String) {
  list.try_map(raw, fn(s) {
    permission.from_string(s)
    |> result.replace_error("unknown permission: " <> s)
  })
}

fn role_to_json(r: Role) -> json.Json {
  json.object([
    #("id", json.string(role.role_id(role.id(r)))),
    #("name", json.string(role.name(r))),
    #("is_owner", json.bool(role.is_owner(r))),
    #(
      "permissions",
      json.array(role.permissions(r), fn(p) {
        json.string(permission.to_string(p))
      }),
    ),
  ])
}

fn ok_json() -> json.Json {
  json.object([#("ok", json.bool(True))])
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
