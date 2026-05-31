//// Member-management HTTP handlers. Adding a member assigns an existing org
//// role to an existing user (by email). Changing/removing the last Owner is
//// refused.

import app/add_member
import app/list_members
import app/remove_member
import app/update_member_role
import conversation.{type RequestBody, type ResponseBody}
import db/membership_repo
import db/role_repo
import db/user_repo
import domain/membership.{type Membership}
import domain/organization
import domain/permission
import domain/role
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/guard
import router/reply

type AddInput {
  AddInput(email: String, role_id: String)
}

type RoleAssignment {
  RoleAssignment(role_id: String)
}

pub fn list(
  deps: Deps,
  user: User,
  org_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.MemberRead)
  let repo = membership_repo.new(deps.db)
  use result <- promise.map(list_members.run(repo, oid))
  case result {
    Ok(members) -> reply.json_response(200, json.array(members, member_to_json))
    Error(list_members.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list members"))
  }
}

pub fn add(
  deps: Deps,
  user: User,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.MemberCreate)
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, add_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"email\" and \"role_id\" strings"),
          ))
        Ok(input) -> {
          use result <- promise.map(add_member.run(
            membership_repo.new(deps.db),
            role_repo.new(deps.db),
            user_repo.new(deps.db),
            deps.generate_id,
            oid,
            input.email,
            input.role_id,
          ))
          case result {
            Ok(member) -> reply.json_response(201, member_to_json(member))
            Error(add_member.InvalidEmail(_)) ->
              reply.json_response(422, error_json("a valid email is required"))
            Error(add_member.InvalidRoleId(_)) ->
              reply.json_response(422, error_json("a role_id is required"))
            Error(add_member.RoleNotFound) ->
              reply.json_response(404, error_json("role not found"))
            Error(add_member.UserNotFound) ->
              reply.json_response(404, error_json("no user with that email"))
            Error(add_member.AlreadyMember) ->
              reply.json_response(409, error_json("already a member"))
            Error(add_member.RepoFailed(_)) ->
              reply.json_response(500, error_json("could not add member"))
          }
        }
      }
  }
}

pub fn update_role(
  deps: Deps,
  user: User,
  org_id: String,
  target_user_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.MemberUpdate)
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, role_assignment_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected a \"role_id\" string"),
          ))
        Ok(input) -> {
          use result <- promise.map(update_member_role.run(
            membership_repo.new(deps.db),
            role_repo.new(deps.db),
            oid,
            target_user_id,
            input.role_id,
          ))
          case result {
            Ok(member) -> reply.json_response(200, member_to_json(member))
            Error(update_member_role.NotMember) ->
              reply.json_response(404, error_json("not a member"))
            Error(update_member_role.RoleNotFound) ->
              reply.json_response(404, error_json("role not found"))
            Error(update_member_role.LastOwner) ->
              reply.json_response(409, error_json("cannot demote the last owner"))
            Error(update_member_role.InvalidUserId(_))
            | Error(update_member_role.InvalidRoleId(_)) ->
              reply.json_response(422, error_json("invalid user or role id"))
            Error(update_member_role.RepoFailed(_)) ->
              reply.json_response(500, error_json("could not update member"))
          }
        }
      }
  }
}

pub fn remove(
  deps: Deps,
  user: User,
  org_id: String,
  target_user_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.MemberDelete)
  use result <- promise.map(remove_member.run(
    membership_repo.new(deps.db),
    role_repo.new(deps.db),
    oid,
    target_user_id,
  ))
  case result {
    Ok(Nil) -> reply.json_response(200, ok_json())
    Error(remove_member.NotMember) ->
      reply.json_response(404, error_json("not a member"))
    Error(remove_member.LastOwner) ->
      reply.json_response(409, error_json("cannot remove the last owner"))
    Error(remove_member.InvalidUserId(_)) ->
      reply.json_response(422, error_json("invalid user id"))
    Error(remove_member.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not remove member"))
  }
}

fn add_decoder() -> decode.Decoder(AddInput) {
  use email <- decode.field("email", decode.string)
  use role_id <- decode.field("role_id", decode.string)
  decode.success(AddInput(email:, role_id:))
}

fn role_assignment_decoder() -> decode.Decoder(RoleAssignment) {
  use role_id <- decode.field("role_id", decode.string)
  decode.success(RoleAssignment(role_id:))
}

fn member_to_json(m: Membership) -> json.Json {
  json.object([
    #("id", json.string(membership.membership_id(membership.id(m)))),
    #(
      "organization_id",
      json.string(organization.organization_id(membership.organization_id(m))),
    ),
    #("user_id", json.string(user.user_id(membership.user_id(m)))),
    #("role_id", json.string(role.role_id(membership.role_id(m)))),
  ])
}

fn ok_json() -> json.Json {
  json.object([#("ok", json.bool(True))])
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
