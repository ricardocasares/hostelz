//// The spaces HTTP handlers. Spaces are the bookable inventory tree, nested
//// under their organization and gated by `space:*` permissions:
////   `POST /organizations/:org_id/spaces` (`create`, `space:create`),
////   `GET /organizations/:org_id/spaces` (`list_for_org`, `space:read`),
////   `GET /spaces/:id` (`show`) and `GET /spaces/:id/children`
////   (`list_children`) — both resolve the resource then check `space:read` on
////   its organization.

import app/create_space.{
  type CreateSpaceError, InvalidSpace, ParentDifferentOrganization,
  ParentNotFound, ParentNotGrouping, RepoFailed,
}
import app/find_space
import app/list_child_spaces
import app/list_organization_spaces
import conversation.{type RequestBody, type ResponseBody}
import db/space_repo
import domain/organization.{type OrganizationId}
import domain/permission
import domain/space.{type Space, type SpaceId}
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/option.{type Option, None, Some}
import router/context.{type Deps}
import router/guard
import router/reply

type NewSpace {
  NewSpace(name: String, kind: String, label: String, parent_id: Option(String))
}

pub fn list_for_org(
  deps: Deps,
  user: User,
  org_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(deps, user, org_id, permission.SpaceRead)
  let repo = space_repo.new(deps.db)
  use result <- promise.map(list_organization_spaces.run(repo, oid))
  case result {
    Ok(spaces) -> reply.json_response(200, json.array(spaces, space_to_json))
    Error(list_organization_spaces.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list spaces"))
  }
}

pub fn show(
  deps: Deps,
  user: User,
  id: String,
) -> Promise(Response(ResponseBody)) {
  let repo = space_repo.new(deps.db)
  use result <- promise.await(find_space.run(repo, id))
  case result {
    Error(find_space.NotFound) | Error(find_space.InvalidId(_)) ->
      promise.resolve(reply.json_response(404, error_json("space not found")))
    Error(find_space.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load space"),
      ))
    Ok(s) -> {
      use <- guard.require_permission_for_org(
        deps,
        user,
        space.organization_id(s),
        permission.SpaceRead,
      )
      promise.resolve(reply.json_response(200, space_to_json(s)))
    }
  }
}

pub fn list_children(
  deps: Deps,
  user: User,
  id: String,
) -> Promise(Response(ResponseBody)) {
  let repo = space_repo.new(deps.db)
  use parent <- promise.await(find_space.run(repo, id))
  case parent {
    Error(find_space.NotFound) | Error(find_space.InvalidId(_)) ->
      promise.resolve(reply.json_response(404, error_json("space not found")))
    Error(find_space.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load space"),
      ))
    Ok(p) -> {
      use <- guard.require_permission_for_org(
        deps,
        user,
        space.organization_id(p),
        permission.SpaceRead,
      )
      use result <- promise.map(list_child_spaces.run(repo, space.id(p)))
      case result {
        Ok(children) ->
          reply.json_response(200, json.array(children, space_to_json))
        Error(list_child_spaces.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not list spaces"))
      }
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
    permission.SpaceCreate,
  )
  create_under_org(deps, oid, req)
}

fn create_under_org(
  deps: Deps,
  organization_id: OrganizationId,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, new_space_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"name\", \"kind\" and \"label\" strings"),
          ))
        Ok(input) -> register(deps, organization_id, input)
      }
  }
}

fn register(
  deps: Deps,
  organization_id: OrganizationId,
  input: NewSpace,
) -> Promise(Response(ResponseBody)) {
  case parse_kind(input.kind), parse_parent(input.parent_id) {
    Error(message), _ ->
      promise.resolve(reply.json_response(422, error_json(message)))
    _, Error(message) ->
      promise.resolve(reply.json_response(422, error_json(message)))
    Ok(is_grouping), Ok(parent_id) -> {
      let repo = space_repo.new(deps.db)
      use result <- promise.map(create_space.run(
        repo,
        deps.generate_id,
        organization_id,
        parent_id,
        is_grouping,
        input.label,
        input.name,
      ))
      case result {
        Ok(saved) -> reply.json_response(201, space_to_json(saved))
        Error(error) -> error_response(error)
      }
    }
  }
}

fn parse_kind(kind: String) -> Result(Bool, String) {
  case kind {
    "unit" -> Ok(False)
    "grouping" -> Ok(True)
    _ -> Error("kind must be \"unit\" or \"grouping\"")
  }
}

fn parse_parent(parent_id: Option(String)) -> Result(Option(SpaceId), String) {
  case parent_id {
    None -> Ok(None)
    Some(raw) ->
      case space.new_id(raw) {
        Ok(id) -> Ok(Some(id))
        Error(_) -> Error("parent_id must not be empty")
      }
  }
}

fn new_space_decoder() -> decode.Decoder(NewSpace) {
  use name <- decode.field("name", decode.string)
  use kind <- decode.field("kind", decode.string)
  use label <- decode.field("label", decode.string)
  use parent_id <- decode.optional_field(
    "parent_id",
    None,
    decode.optional(decode.string),
  )
  decode.success(NewSpace(name:, kind:, label:, parent_id:))
}

fn space_to_json(s: Space) -> json.Json {
  json.object([
    #("id", json.string(space.space_id(space.id(s)))),
    #(
      "organization_id",
      json.string(organization.organization_id(space.organization_id(s))),
    ),
    #(
      "parent_id",
      json.nullable(space.parent_id(s), fn(pid) {
        json.string(space.space_id(pid))
      }),
    ),
    #("kind", json.string(kind_to_string(s))),
    #("label", json.string(space.kind_label(space.kind(s)))),
    #("name", json.string(space.name(s))),
  ])
}

fn kind_to_string(s: Space) -> String {
  case space.kind_is_grouping(space.kind(s)) {
    True -> "grouping"
    False -> "unit"
  }
}

fn error_response(error: CreateSpaceError) -> Response(ResponseBody) {
  case error {
    InvalidSpace(reason) ->
      reply.json_response(422, error_json(space_error_message(reason)))
    ParentNotFound | ParentDifferentOrganization ->
      reply.json_response(404, error_json("parent space not found"))
    ParentNotGrouping ->
      reply.json_response(
        422,
        error_json("parent space cannot contain children"),
      )
    RepoFailed(_) ->
      reply.json_response(500, error_json("could not save space"))
  }
}

fn space_error_message(error: space.SpaceError) -> String {
  case error {
    space.EmptyId -> "id must not be empty"
    space.EmptyName -> "name must not be empty"
    space.EmptyLabel -> "label must not be empty"
  }
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
