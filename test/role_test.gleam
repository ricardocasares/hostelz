import domain/organization
import domain/permission
import domain/role

fn an_org() -> organization.OrganizationId {
  let assert Ok(o) = organization.new_id("o1")
  o
}

pub fn owner_allows_every_permission_test() {
  let assert Ok(rid) = role.new_id("r1")
  let owner = role.owner(rid, an_org())
  assert role.is_owner(owner) == True
  assert role.allows(owner, permission.SpaceCreate) == True
  assert role.allows(owner, permission.OrgDelete) == True
  assert role.allows(owner, permission.MemberDelete) == True
}

pub fn custom_role_allows_only_listed_test() {
  let assert Ok(rid) = role.new_id("r1")
  let assert Ok(r) =
    role.new(rid, an_org(), "Front Desk", [
      permission.GuestCreate,
      permission.GuestRead,
    ])
  assert role.is_owner(r) == False
  assert role.allows(r, permission.GuestCreate) == True
  assert role.allows(r, permission.SpaceCreate) == False
}

pub fn rejects_empty_name_test() {
  let assert Ok(rid) = role.new_id("r1")
  assert role.new(rid, an_org(), "  ", []) == Error(role.EmptyName)
}

pub fn set_permissions_replaces_the_set_test() {
  let assert Ok(rid) = role.new_id("r1")
  let assert Ok(r) = role.new(rid, an_org(), "R", [permission.GuestRead])
  let updated = role.set_permissions(r, [permission.SpaceCreate])
  assert role.allows(updated, permission.SpaceCreate) == True
  assert role.allows(updated, permission.GuestRead) == False
}
