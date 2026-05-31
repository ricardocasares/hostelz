//// The organizations HTTP handlers.
////
//// `POST /organizations` (`create`) creates one from `{"name","slug"}` and
//// makes the caller its Owner; any authenticated user may. `GET /organizations`
//// (`list`) returns the caller's organizations. `GET /organizations/:id`
//// (`show`) returns one, gated by `org:read` membership.

import app/create_organization.{
  type CreateOrganizationError, InvalidOrganization, InvalidSlug, RepoFailed,
  SlugTaken,
}
import app/find_organization
import app/list_user_organizations
import conversation.{type RequestBody, type ResponseBody}
import db/membership_repo
import db/organization_repo
import db/role_repo
import domain/organization.{type Organization}
import domain/permission
import domain/slug
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import router/context.{type Deps}
import router/guard
import router/reply

type NewOrganization {
  NewOrganization(name: String, slug: String)
}

/// `GET /organizations` — the organizations the current user belongs to.
pub fn list(deps: Deps, user: User) -> Promise(Response(ResponseBody)) {
  let repo = organization_repo.new(deps.db)
  use result <- promise.map(list_user_organizations.run(repo, user.id(user)))
  case result {
    Ok(orgs) -> reply.json_response(200, json.array(orgs, org_to_json))
    Error(list_user_organizations.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list organizations"))
  }
}

/// `GET /organizations/:id` — a single organization, for its members.
pub fn show(
  deps: Deps,
  user: User,
  id: String,
) -> Promise(Response(ResponseBody)) {
  use _oid <- guard.require_permission(deps, user, id, permission.OrgRead)
  let repo = organization_repo.new(deps.db)
  use result <- promise.map(find_organization.run(repo, id))
  case result {
    Ok(org) -> reply.json_response(200, org_to_json(org))
    Error(find_organization.NotFound) | Error(find_organization.InvalidId(_)) ->
      reply.json_response(404, error_json("organization not found"))
    Error(find_organization.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not load organization"))
  }
}

/// `POST /organizations` — create one and become its Owner.
pub fn create(
  deps: Deps,
  user: User,
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
          use result <- promise.map(create_organization.run(
            organization_repo.new(deps.db),
            role_repo.new(deps.db),
            membership_repo.new(deps.db),
            deps.generate_id,
            user.id(user),
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
    InvalidOrganization(_) ->
      reply.json_response(422, error_json("name must not be empty"))
    InvalidSlug(reason) ->
      reply.json_response(422, error_json(slug_error_message(reason)))
    SlugTaken -> reply.json_response(409, error_json("slug already taken"))
    RepoFailed(_) ->
      reply.json_response(500, error_json("could not save organization"))
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
