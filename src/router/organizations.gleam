//// The organizations HTTP handlers — pure translation between the wire and the
//// `create_organization` / `list_organizations` / `find_organization` use
//// cases.
////
//// `POST /organizations` (`create`) creates one from `{"name","slug"}`; the id
//// is minted server-side. `GET /organizations` (`list`) returns every org;
//// `GET /organizations/:id` (`show`) returns one or 404.
////
//// Validation failures are the client's fault (422); a taken slug is a conflict
//// (409); a repository failure is ours (500) and stays opaque.

import app/create_organization.{
  type CreateOrganizationError, InvalidOrganization, InvalidSlug, RepoFailed,
  SlugTaken,
}
import app/find_organization
import app/list_organizations
import conversation.{type RequestBody, type ResponseBody}
import db/organization_repo
import domain/organization.{type Organization}
import domain/slug
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/reply

/// The shape we accept in the request body.
type NewOrganization {
  NewOrganization(name: String, slug: String)
}

/// `GET /organizations` — every organization as a JSON array, newest first.
pub fn list(deps: Deps) -> Promise(Response(ResponseBody)) {
  let repo = organization_repo.new(deps.db)
  use result <- promise.map(list_organizations.run(repo))
  case result {
    Ok(orgs) -> reply.json_response(200, json.array(orgs, org_to_json))
    Error(list_organizations.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list organizations"))
  }
}

/// `GET /organizations/:id` — a single organization by id, or 404.
pub fn show(deps: Deps, id: String) -> Promise(Response(ResponseBody)) {
  let repo = organization_repo.new(deps.db)
  use result <- promise.map(find_organization.run(repo, id))
  case result {
    Ok(org) -> reply.json_response(200, org_to_json(org))
    Error(find_organization.InvalidId(reason)) ->
      reply.json_response(422, error_json(organization_error_message(reason)))
    Error(find_organization.NotFound) ->
      reply.json_response(404, error_json("organization not found"))
    Error(find_organization.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not load organization"))
  }
}

/// `POST /organizations` — create one from a JSON body `{"name","slug"}`.
pub fn create(
  deps: Deps,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, new_organization_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json("expected \"name\" and \"slug\" strings"),
          ))
        Ok(input) -> {
          let repo = organization_repo.new(deps.db)
          use result <- promise.map(create_organization.run(
            repo,
            deps.generate_id,
            input.slug,
            input.name,
          ))
          case result {
            Ok(saved) -> reply.json_response(201, org_to_json(saved))
            Error(error) -> error_response(error)
          }
        }
      }
  }
}

fn new_organization_decoder() -> decode.Decoder(NewOrganization) {
  use name <- decode.field("name", decode.string)
  use slug <- decode.field("slug", decode.string)
  decode.success(NewOrganization(name:, slug:))
}

fn org_to_json(o: Organization) -> json.Json {
  json.object([
    #("id", json.string(organization.organization_id(organization.id(o)))),
    #("slug", json.string(slug.to_string(organization.slug(o)))),
    #("name", json.string(organization.name(o))),
  ])
}

fn error_response(error: CreateOrganizationError) -> Response(ResponseBody) {
  case error {
    InvalidOrganization(reason) ->
      reply.json_response(422, error_json(organization_error_message(reason)))
    InvalidSlug(reason) ->
      reply.json_response(422, error_json(slug_error_message(reason)))
    SlugTaken -> reply.json_response(409, error_json("slug already taken"))
    RepoFailed(_) ->
      reply.json_response(500, error_json("could not save organization"))
  }
}

fn organization_error_message(error: organization.OrganizationError) -> String {
  case error {
    organization.EmptyId -> "id must not be empty"
    organization.EmptyName -> "name must not be empty"
  }
}

fn slug_error_message(error: slug.SlugError) -> String {
  case error {
    slug.Empty -> "slug must not be empty"
    slug.Invalid -> "slug must be lowercase letters, numbers and single hyphens"
  }
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
