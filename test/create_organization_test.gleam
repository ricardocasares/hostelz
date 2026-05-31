//// Unit tests for the create-organization use case, using a fake
//// `OrganizationRepo`. The key case: the adapter reports a unique-constraint
//// violation as `RepoError.Conflict`, and the use case maps it to `SlugTaken`
//// — this is the uniqueness contract, proven for real against the DB in
//// `organization_persistence_test`.

import app/create_organization
import domain/organization
import domain/organization_repo.{OrganizationRepo}
import gleam/javascript/promise

fn gen(id: String) -> fn() -> String {
  fn() { id }
}

fn repo_with_save(
  save: fn(organization.Organization) ->
    promise.Promise(Result(Nil, organization_repo.RepoError)),
) -> organization_repo.OrganizationRepo {
  OrganizationRepo(
    save: save,
    find: fn(_) { promise.resolve(Error(organization_repo.NotFound)) },
    find_by_slug: fn(_) { promise.resolve(Error(organization_repo.NotFound)) },
    list_all: fn() { promise.resolve(Ok([])) },
  )
}

fn ok_repo() -> organization_repo.OrganizationRepo {
  repo_with_save(fn(_) { promise.resolve(Ok(Nil)) })
}

fn conflict_repo() -> organization_repo.OrganizationRepo {
  repo_with_save(fn(_) {
    promise.resolve(Error(organization_repo.Conflict("slug already taken")))
  })
}

pub fn create_succeeds_test() {
  use result <- promise.map(create_organization.run(
    ok_repo(),
    gen("org_1"),
    "backpackers",
    "Backpackers",
  ))
  let assert Ok(o) = result
  assert organization.name(o) == "Backpackers"
}

pub fn create_rejects_bad_slug_test() {
  use result <- promise.map(create_organization.run(
    ok_repo(),
    gen("org_1"),
    "Bad Slug",
    "Backpackers",
  ))
  let assert Error(create_organization.InvalidSlug(_)) = result
}

pub fn create_rejects_empty_name_test() {
  use result <- promise.map(create_organization.run(
    ok_repo(),
    gen("org_1"),
    "backpackers",
    "  ",
  ))
  let assert Error(create_organization.InvalidOrganization(_)) = result
}

pub fn duplicate_slug_is_slug_taken_test() {
  use result <- promise.map(create_organization.run(
    conflict_repo(),
    gen("org_1"),
    "backpackers",
    "Backpackers",
  ))
  assert result == Error(create_organization.SlugTaken)
}
