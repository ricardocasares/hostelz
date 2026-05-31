//// Authentication and authorization guards, in the `use <-` continuation style.
////
//// `require_auth` resolves the Bearer token to the current user (401 otherwise)
//// — wrapped once around the protected route branch. `require_permission`
//// checks that the user holds a permission in an organization (403 otherwise)
//// — called per handler, since the required permission is route-specific.

import app/authenticate
import app/authorize
import conversation.{type RequestBody, type ResponseBody}
import db/membership_repo
import db/role_repo
import db/session_repo
import db/user_repo
import domain/organization.{type OrganizationId}
import domain/permission.{type Permission}
import domain/user.{type User}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/reply

/// Extract a Bearer token from the Authorization header.
pub fn bearer_token(req: Request(RequestBody)) -> Result(String, Nil) {
  case request.get_header(req, "authorization") {
    Ok("Bearer " <> token) -> Ok(token)
    _ -> Error(Nil)
  }
}

pub fn require_auth(
  deps: Deps,
  req: Request(RequestBody),
  next: fn(User) -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  case bearer_token(req) {
    Error(Nil) -> promise.resolve(unauthorized())
    Ok(token) -> {
      let sessions = session_repo.new(deps.db)
      let users = user_repo.new(deps.db)
      use result <- promise.await(authenticate.run(sessions, users, token))
      case result {
        Ok(user) -> next(user)
        Error(authenticate.InvalidSession) -> promise.resolve(unauthorized())
        Error(authenticate.RepoFailed(_)) -> promise.resolve(server_error())
      }
    }
  }
}

/// Require `perm` in the organization named by a raw id from the path.
pub fn require_permission(
  deps: Deps,
  user: User,
  org_id: String,
  perm: Permission,
  next: fn(OrganizationId) -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  case organization.new_id(org_id) {
    Error(_) -> promise.resolve(not_found("organization not found"))
    Ok(oid) ->
      require_permission_for_org(deps, user, oid, perm, fn() { next(oid) })
  }
}

/// Require `perm` in an already-validated organization (resource-first routes).
pub fn require_permission_for_org(
  deps: Deps,
  user: User,
  org_id: OrganizationId,
  perm: Permission,
  next: fn() -> Promise(Response(ResponseBody)),
) -> Promise(Response(ResponseBody)) {
  let memberships = membership_repo.new(deps.db)
  let roles = role_repo.new(deps.db)
  use result <- promise.await(authorize.run(
    memberships,
    roles,
    org_id,
    user.id(user),
    perm,
  ))
  case result {
    Ok(Nil) -> next()
    Error(authorize.NotMember) -> promise.resolve(forbidden())
    Error(authorize.Forbidden) -> promise.resolve(forbidden())
    Error(authorize.RepoFailed(_)) -> promise.resolve(server_error())
  }
}

fn unauthorized() -> Response(ResponseBody) {
  reply.json_response(401, error_json("authentication required"))
}

fn forbidden() -> Response(ResponseBody) {
  reply.json_response(403, error_json("forbidden"))
}

fn server_error() -> Response(ResponseBody) {
  reply.json_response(500, error_json("internal error"))
}

fn not_found(message: String) -> Response(ResponseBody) {
  reply.json_response(404, error_json(message))
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
