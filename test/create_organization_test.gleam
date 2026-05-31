//// Unit tests for the reworked create-organization use case (now seeds the
//// Owner role + the creator's membership). Fake repos.

import app/create_organization
import domain/membership_repo.{MembershipRepo}
import domain/organization
import domain/organization_repo.{OrganizationRepo}
import domain/role_repo.{RoleRepo}
import domain/user
import gleam/javascript/promise

fn gen(id: String) -> fn() -> String {
  fn() { id }
}

fn an_owner() -> user.UserId {
  let assert Ok(uid) = user.new_id("u_1")
  uid
}

fn ok_orgs() -> organization_repo.OrganizationRepo {
  OrganizationRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(Error(organization_repo.NotFound)) },
    find_by_slug: fn(_) { promise.resolve(Error(organization_repo.NotFound)) },
    list_all: fn() { promise.resolve(Ok([])) },
    list_for_user: fn(_) { promise.resolve(Ok([])) },
  )
}

fn slug_taken_orgs() -> organization_repo.OrganizationRepo {
  OrganizationRepo(
    ..ok_orgs(),
    save: fn(_) { promise.resolve(Error(organization_repo.Conflict("dup"))) },
  )
}

fn ok_roles() -> role_repo.RoleRepo {
  RoleRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(Error(role_repo.NotFound)) },
    list_by_organization: fn(_) { promise.resolve(Ok([])) },
    delete: fn(_) { promise.resolve(Ok(Nil)) },
  )
}

fn ok_memberships() -> membership_repo.MembershipRepo {
  MembershipRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_, _) { promise.resolve(Error(membership_repo.NotFound)) },
    list_by_organization: fn(_) { promise.resolve(Ok([])) },
    delete: fn(_, _) { promise.resolve(Ok(Nil)) },
    count_owners: fn(_) { promise.resolve(Ok(1)) },
  )
}

pub fn create_succeeds_test() {
  use result <- promise.map(create_organization.run(
    ok_orgs(),
    ok_roles(),
    ok_memberships(),
    gen("org_1"),
    an_owner(),
    "acme",
    "Acme",
  ))
  let assert Ok(org) = result
  assert organization.name(org) == "Acme"
}

pub fn create_rejects_bad_slug_test() {
  use result <- promise.map(create_organization.run(
    ok_orgs(),
    ok_roles(),
    ok_memberships(),
    gen("org_1"),
    an_owner(),
    "Bad Slug",
    "Acme",
  ))
  let assert Error(create_organization.InvalidSlug(_)) = result
}

pub fn create_rejects_empty_name_test() {
  use result <- promise.map(create_organization.run(
    ok_orgs(),
    ok_roles(),
    ok_memberships(),
    gen("org_1"),
    an_owner(),
    "acme",
    "  ",
  ))
  let assert Error(create_organization.InvalidOrganization(_)) = result
}

pub fn duplicate_slug_is_slug_taken_test() {
  use result <- promise.map(create_organization.run(
    slug_taken_orgs(),
    ok_roles(),
    ok_memberships(),
    gen("org_1"),
    an_owner(),
    "acme",
    "Acme",
  ))
  assert result == Error(create_organization.SlugTaken)
}
