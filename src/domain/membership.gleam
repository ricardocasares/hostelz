//// A membership joins a user to an organization with exactly one role. Unique
//// on (organization, user) — enforced at the database boundary.

import domain/organization.{type OrganizationId}
import domain/role.{type RoleId}
import domain/user.{type UserId}
import gleam/string

pub opaque type MembershipId {
  MembershipId(value: String)
}

pub opaque type Membership {
  Membership(
    id: MembershipId,
    organization_id: OrganizationId,
    user_id: UserId,
    role_id: RoleId,
  )
}

pub type MembershipError {
  EmptyId
}

pub fn new_id(raw: String) -> Result(MembershipId, MembershipError) {
  let raw = string.trim(raw)
  case string.is_empty(raw) {
    True -> Error(EmptyId)
    False -> Ok(MembershipId(raw))
  }
}

/// All inputs are already-validated value objects, so construction can't fail.
pub fn new(
  id: MembershipId,
  organization_id: OrganizationId,
  user_id: UserId,
  role_id: RoleId,
) -> Membership {
  Membership(id, organization_id, user_id, role_id)
}

// accessors
pub fn id(membership: Membership) -> MembershipId {
  membership.id
}

pub fn membership_id(id: MembershipId) -> String {
  id.value
}

pub fn organization_id(membership: Membership) -> OrganizationId {
  membership.organization_id
}

pub fn user_id(membership: Membership) -> UserId {
  membership.user_id
}

pub fn role_id(membership: Membership) -> RoleId {
  membership.role_id
}

/// Reassign the membership to a different role (same identity).
pub fn assign_role(membership: Membership, role_id: RoleId) -> Membership {
  Membership(..membership, role_id:)
}
