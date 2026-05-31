//// A role is a named, per-organization bundle of permissions. The special
//// `Owner` role (`is_owner`) implicitly holds *every* permission and is
//// immutable — `allows` short-circuits on it, so it stays correct as the
//// catalog grows. Other roles allow exactly their listed permissions.

import domain/organization.{type OrganizationId}
import domain/permission.{type Permission}
import gleam/list
import gleam/string

pub opaque type RoleId {
  RoleId(value: String)
}

pub opaque type Role {
  Role(
    id: RoleId,
    organization_id: OrganizationId,
    name: String,
    is_owner: Bool,
    permissions: List(Permission),
  )
}

pub type RoleError {
  EmptyId
  EmptyName
}

pub fn new_id(raw: String) -> Result(RoleId, RoleError) {
  let raw = string.trim(raw)
  case string.is_empty(raw) {
    True -> Error(EmptyId)
    False -> Ok(RoleId(raw))
  }
}

fn build(
  id: RoleId,
  organization_id: OrganizationId,
  name: String,
  is_owner: Bool,
  permissions: List(Permission),
) -> Result(Role, RoleError) {
  case string.trim(name) {
    "" -> Error(EmptyName)
    trimmed ->
      Ok(Role(id, organization_id, trimmed, is_owner, list.unique(permissions)))
  }
}

/// A custom (non-owner) role with an explicit permission set.
pub fn new(
  id: RoleId,
  organization_id: OrganizationId,
  name: String,
  permissions: List(Permission),
) -> Result(Role, RoleError) {
  build(id, organization_id, name, False, permissions)
}

/// The system Owner role — all permissions implied, immutable.
pub fn owner(id: RoleId, organization_id: OrganizationId) -> Role {
  let assert Ok(role) = build(id, organization_id, "Owner", True, [])
  role
}

/// Rebuild a stored role faithfully (used by the adapter on load).
pub fn restore(
  id: RoleId,
  organization_id: OrganizationId,
  name: String,
  is_owner: Bool,
  permissions: List(Permission),
) -> Result(Role, RoleError) {
  build(id, organization_id, name, is_owner, permissions)
}

// accessors
pub fn id(role: Role) -> RoleId {
  role.id
}

pub fn role_id(id: RoleId) -> String {
  id.value
}

pub fn organization_id(role: Role) -> OrganizationId {
  role.organization_id
}

pub fn name(role: Role) -> String {
  role.name
}

pub fn is_owner(role: Role) -> Bool {
  role.is_owner
}

pub fn permissions(role: Role) -> List(Permission) {
  role.permissions
}

/// The authorization decision: Owner allows everything; any other role allows
/// exactly its listed permissions.
pub fn allows(role: Role, needed: Permission) -> Bool {
  role.is_owner || list.contains(role.permissions, needed)
}

// transitions (custom roles only — callers must refuse editing an owner role)
pub fn rename(role: Role, new_name: String) -> Result(Role, RoleError) {
  case string.trim(new_name) {
    "" -> Error(EmptyName)
    trimmed -> Ok(Role(..role, name: trimmed))
  }
}

pub fn set_permissions(role: Role, permissions: List(Permission)) -> Role {
  Role(..role, permissions: list.unique(permissions))
}

pub fn same_role(a: Role, b: Role) -> Bool {
  a.id == b.id
}
