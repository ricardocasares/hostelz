//// Unit tests for the create-space use case with a fake `SpaceRepo`. Covers the
//// parent rules the domain can't self-check (the child only holds parent_id):
//// the parent must exist, be a grouping, and share the organization.

import app/create_space
import domain/organization
import domain/space
import domain/space_repo.{SpaceRepo}
import gleam/javascript/promise
import gleam/option.{None, Some}

fn gen(id: String) -> fn() -> String {
  fn() { id }
}

fn an_org_id() -> organization.OrganizationId {
  let assert Ok(id) = organization.new_id("org_1")
  id
}

fn repo_finding(
  found: fn() -> Result(space.Space, space_repo.RepoError),
) -> space_repo.SpaceRepo {
  SpaceRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(found()) },
    list_by_organization: fn(_) { promise.resolve(Ok([])) },
    list_children: fn(_) { promise.resolve(Ok([])) },
  )
}

fn no_parent_repo() -> space_repo.SpaceRepo {
  repo_finding(fn() { Error(space_repo.NotFound) })
}

fn grouping_space(org: organization.OrganizationId, id: String) -> space.Space {
  let assert Ok(sid) = space.new_id(id)
  let assert Ok(k) = space.grouping("room")
  let assert Ok(s) = space.new(sid, org, None, k, "Room")
  s
}

fn unit_space(org: organization.OrganizationId, id: String) -> space.Space {
  let assert Ok(sid) = space.new_id(id)
  let assert Ok(k) = space.unit("bed")
  let assert Ok(s) = space.new(sid, org, None, k, "Bed")
  s
}

pub fn create_root_succeeds_test() {
  use result <- promise.map(create_space.run(
    no_parent_repo(),
    gen("sp_1"),
    an_org_id(),
    None,
    True,
    "hostel",
    "Main",
  ))
  let assert Ok(s) = result
  assert space.name(s) == "Main"
  assert space.parent_id(s) == None
}

pub fn create_child_under_grouping_succeeds_test() {
  let parent = grouping_space(an_org_id(), "sp_parent")
  let assert Ok(pid) = space.new_id("sp_parent")
  use result <- promise.map(create_space.run(
    repo_finding(fn() { Ok(parent) }),
    gen("sp_child"),
    an_org_id(),
    Some(pid),
    False,
    "bed",
    "Bed 1",
  ))
  let assert Ok(s) = result
  assert space.parent_id(s) == Some(pid)
}

pub fn create_child_under_unit_is_rejected_test() {
  let parent = unit_space(an_org_id(), "sp_bed")
  let assert Ok(pid) = space.new_id("sp_bed")
  use result <- promise.map(create_space.run(
    repo_finding(fn() { Ok(parent) }),
    gen("sp_child"),
    an_org_id(),
    Some(pid),
    False,
    "bed",
    "Bed 2",
  ))
  assert result == Error(create_space.ParentNotGrouping)
}

pub fn create_child_missing_parent_is_rejected_test() {
  let assert Ok(pid) = space.new_id("sp_missing")
  use result <- promise.map(create_space.run(
    no_parent_repo(),
    gen("sp_child"),
    an_org_id(),
    Some(pid),
    False,
    "bed",
    "Bed",
  ))
  assert result == Error(create_space.ParentNotFound)
}

pub fn create_child_in_different_org_is_rejected_test() {
  let assert Ok(other_org) = organization.new_id("org_other")
  let parent = grouping_space(other_org, "sp_parent")
  let assert Ok(pid) = space.new_id("sp_parent")
  use result <- promise.map(create_space.run(
    repo_finding(fn() { Ok(parent) }),
    gen("sp_child"),
    an_org_id(),
    Some(pid),
    False,
    "bed",
    "Bed",
  ))
  assert result == Error(create_space.ParentDifferentOrganization)
}

pub fn create_rejects_empty_label_test() {
  use result <- promise.map(create_space.run(
    no_parent_repo(),
    gen("sp_1"),
    an_org_id(),
    None,
    True,
    "  ",
    "Main",
  ))
  assert result == Error(create_space.InvalidSpace(space.EmptyLabel))
}

pub fn create_rejects_empty_name_test() {
  use result <- promise.map(create_space.run(
    no_parent_repo(),
    gen("sp_1"),
    an_org_id(),
    None,
    True,
    "hostel",
    "  ",
  ))
  assert result == Error(create_space.InvalidSpace(space.EmptyName))
}
