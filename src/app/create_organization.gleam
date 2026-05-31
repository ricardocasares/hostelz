//// Application use case: create an organization.
////
//// Validates the raw slug and name through the domain (format invariants),
//// then persists via the repository port. Slug *uniqueness* is a set-level
//// invariant no single aggregate can enforce, so it lives in the database
//// (unique index) and surfaces as `RepoError.Conflict`, which we map to
//// `SlugTaken` — authoritative and free of the read-then-write race a
//// pre-check would have.

import domain/organization.{type Organization}
import domain/organization_repo.{type OrganizationRepo, type RepoError}
import domain/slug
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type CreateOrganizationError {
  InvalidOrganization(organization.OrganizationError)
  InvalidSlug(slug.SlugError)
  SlugTaken
  RepoFailed(RepoError)
}

pub fn run(
  repo: OrganizationRepo,
  generate_id: fn() -> String,
  raw_slug: String,
  name: String,
) -> Promise(Result(Organization, CreateOrganizationError)) {
  case build(generate_id(), raw_slug, name) {
    Error(error) -> promise.resolve(Error(error))
    Ok(org) -> {
      use saved <- promise.map(repo.save(org))
      saved
      |> result.replace(org)
      |> result.map_error(to_error)
    }
  }
}

fn build(
  id: String,
  raw_slug: String,
  name: String,
) -> Result(Organization, CreateOrganizationError) {
  use oid <- result.try(
    organization.new_id(id) |> result.map_error(InvalidOrganization),
  )
  use org_slug <- result.try(
    slug.new(raw_slug) |> result.map_error(InvalidSlug),
  )
  organization.new(oid, org_slug, name)
  |> result.map_error(InvalidOrganization)
}

fn to_error(error: RepoError) -> CreateOrganizationError {
  case error {
    organization_repo.Conflict(_) -> SlugTaken
    other -> RepoFailed(other)
  }
}
