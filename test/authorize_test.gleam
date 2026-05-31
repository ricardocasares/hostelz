//// Unit tests for the authorization use case with fake repos: non-members are
//// rejected, Owner is allowed anything, a custom role allows exactly its set.

import app/authorize
import domain/membership.{type Membership}
import domain/membership_repo.{type MembershipRepo, MembershipRepo}
import domain/organization
import domain/permission
import domain/repo_error
import domain/role.{type Role}
import domain/role_repo.{type RoleRepo, RoleRepo}
import domain/user
import gleam/javascript/promise

fn an_org() -> organization.OrganizationId {
  let assert Ok(o) = organization.new_id("o1")
  o
}

fn a_user() -> user.UserId {
  let assert Ok(u) = user.new_id("u1")
  u
}

fn a_membership(role_id: role.RoleId) -> Membership {
  let assert Ok(mid) = membership.new_id("m1")
  membership.new(mid, an_org(), a_user(), role_id)
}

fn membership_repo_returning(
  result: Result(Membership, repo_error.RepoError),
) -> MembershipRepo {
  MembershipRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_, _) { promise.resolve(result) },
    list_by_organization: fn(_) { promise.resolve(Ok([])) },
    delete: fn(_, _) { promise.resolve(Ok(Nil)) },
    count_owners: fn(_) { promise.resolve(Ok(1)) },
  )
}

fn role_repo_returning(result: Result(Role, repo_error.RepoError)) -> RoleRepo {
  RoleRepo(
    save: fn(_) { promise.resolve(Ok(Nil)) },
    find: fn(_) { promise.resolve(result) },
    list_by_organization: fn(_) { promise.resolve(Ok([])) },
    delete: fn(_) { promise.resolve(Ok(Nil)) },
  )
}

pub fn non_member_is_not_member_test() {
  use result <- promise.map(authorize.run(
    membership_repo_returning(Error(repo_error.NotFound)),
    role_repo_returning(Error(repo_error.NotFound)),
    an_org(),
    a_user(),
    permission.SpaceRead,
  ))
  assert result == Error(authorize.NotMember)
}

pub fn owner_is_allowed_anything_test() {
  let assert Ok(rid) = role.new_id("r1")
  let owner = role.owner(rid, an_org())
  use result <- promise.map(authorize.run(
    membership_repo_returning(Ok(a_membership(rid))),
    role_repo_returning(Ok(owner)),
    an_org(),
    a_user(),
    permission.OrgDelete,
  ))
  assert result == Ok(Nil)
}

pub fn role_without_permission_is_forbidden_test() {
  let assert Ok(rid) = role.new_id("r1")
  let assert Ok(staff) =
    role.new(rid, an_org(), "Staff", [permission.GuestRead])
  use result <- promise.map(authorize.run(
    membership_repo_returning(Ok(a_membership(rid))),
    role_repo_returning(Ok(staff)),
    an_org(),
    a_user(),
    permission.SpaceCreate,
  ))
  assert result == Error(authorize.Forbidden)
}

pub fn role_with_permission_is_allowed_test() {
  let assert Ok(rid) = role.new_id("r1")
  let assert Ok(staff) =
    role.new(rid, an_org(), "Staff", [permission.SpaceCreate])
  use result <- promise.map(authorize.run(
    membership_repo_returning(Ok(a_membership(rid))),
    role_repo_returning(Ok(staff)),
    an_org(),
    a_user(),
    permission.SpaceCreate,
  ))
  assert result == Ok(Nil)
}
