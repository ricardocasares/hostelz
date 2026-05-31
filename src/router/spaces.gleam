//// The spaces HTTP handlers — pure translation between the wire and the
//// `create_space` / `list_organization_spaces` / `find_space` /
//// `list_child_spaces` use cases.
////
//// Spaces are the bookable inventory tree, nested under their organization:
////   `POST /organizations/:org_id/spaces` (`create`) from a JSON body
////   `{"name","kind":"unit"|"grouping","label","parent_id"?}` — omit `parent_id`
////   for a root. The org is resolved first (404 if unknown); the create use
////   case then enforces the parent rules (exists, is a grouping, same org).
////   `GET /organizations/:org_id/spaces` (`list_for_org`) lists the org's
////   spaces; `GET /spaces/:id` (`show`) one; `GET /spaces/:id/children`
////   (`list_children`) the direct children.

import app/create_space.{
  type CreateSpaceError, InvalidSpace, ParentDifferentOrganization,
  ParentNotFound, ParentNotGrouping, RepoFailed,
}
import app/find_organization
import app/find_space
import app/list_child_spaces
import app/list_organization_spaces
import conversation.{type RequestBody, type ResponseBody}
import db/organization_repo
import db/space_repo
import domain/organization
import domain/space.{type Space, type SpaceId}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/option.{type Option, None, Some}
import router/context.{type Deps}
import router/reply

/// The shape we accept in the request body. `parent_id` is optional — absent
/// means a root space.
type NewSpace {
  NewSpace(name: String, kind: String, label: String, parent_id: Option(String))
}

/// `GET /organizations/:org_id/spaces` — the org's spaces (flat; the caller
/// assembles the tree from each space's parent_id).
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
      let repo = space_repo.new(deps.db)
      use result <- promise.map(list_organization_spaces.run(repo, oid))
      case result {
        Ok(spaces) -> reply.json_response(200, json.array(spaces, space_to_json))
        Error(list_organization_spaces.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not list spaces"))
      }
    }
  }
}

/// `GET /spaces/:id` — a single space by id, or 404.
pub fn show(deps: Deps, id: String) -> Promise(Response(ResponseBody)) {
  let repo = space_repo.new(deps.db)
  use result <- promise.map(find_space.run(repo, id))
  case result {
    Ok(s) -> reply.json_response(200, space_to_json(s))
    Error(find_space.InvalidId(reason)) ->
      reply.json_response(422, error_json(space_error_message(reason)))
    Error(find_space.NotFound) ->
      reply.json_response(404, error_json("space not found"))
    Error(find_space.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not load space"))
  }
}

/// `GET /spaces/:id/children` — the direct children of a space.
pub fn list_children(deps: Deps, id: String) -> Promise(Response(ResponseBody)) {
  case space.new_id(id) {
    Error(reason) ->
      promise.resolve(reply.json_response(
        422,
        error_json(space_error_message(reason)),
      ))
    Ok(sid) -> {
      let repo = space_repo.new(deps.db)
      use result <- promise.map(list_child_spaces.run(repo, sid))
      case result {
        Ok(children) ->
          reply.json_response(200, json.array(children, space_to_json))
        Error(list_child_spaces.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not list spaces"))
      }
    }
  }
}

/// `POST /organizations/:org_id/spaces` — create a space under an org.
pub fn create(
  deps: Deps,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  // Resolve the org first: validates the id and confirms it exists, so an
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
  organization_id: organization.OrganizationId,
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
            error_json(
              "expected \"name\", \"kind\" and \"label\" strings",
            ),
          ))
        Ok(input) -> register(deps, organization_id, input)
      }
  }
}

fn register(
  deps: Deps,
  organization_id: organization.OrganizationId,
  input: NewSpace,
) -> Promise(Response(ResponseBody)) {
  case parse_kind(input.kind), parse_parent(input.parent_id) {
    Error(message), _ -> promise.resolve(reply.json_response(422, error_json(message)))
    _, Error(message) -> promise.resolve(reply.json_response(422, error_json(message)))
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
    // Don't leak whether a parent exists in another org.
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

fn organization_error_message(error: organization.OrganizationError) -> String {
  case error {
    organization.EmptyId -> "organization id must not be empty"
    organization.EmptyName -> "organization name must not be empty"
  }
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
