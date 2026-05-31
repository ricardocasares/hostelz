//// The permission catalog — the *enforcement currency*. Routes check a
//// `Permission`, never a role name. The catalog is a code-defined, exhaustive
//// sum type: roles (data) compose permissions from it, but no permission can
//// exist that no code enforces. Fine-grained CRUD per resource; some
//// (update/delete) are defined ahead of the routes that will use them.

pub type Permission {
  OrgRead
  OrgUpdate
  OrgDelete
  MemberCreate
  MemberRead
  MemberUpdate
  MemberDelete
  RoleCreate
  RoleRead
  RoleUpdate
  RoleDelete
  SpaceCreate
  SpaceRead
  SpaceUpdate
  SpaceDelete
  GuestCreate
  GuestRead
  GuestUpdate
  GuestDelete
}

/// Every permission — for validation and for listing the catalog over the wire.
pub const catalog: List(Permission) = [
  OrgRead, OrgUpdate, OrgDelete, MemberCreate, MemberRead, MemberUpdate,
  MemberDelete, RoleCreate, RoleRead, RoleUpdate, RoleDelete, SpaceCreate,
  SpaceRead, SpaceUpdate, SpaceDelete, GuestCreate, GuestRead, GuestUpdate,
  GuestDelete,
]

pub fn to_string(permission: Permission) -> String {
  case permission {
    OrgRead -> "org:read"
    OrgUpdate -> "org:update"
    OrgDelete -> "org:delete"
    MemberCreate -> "member:create"
    MemberRead -> "member:read"
    MemberUpdate -> "member:update"
    MemberDelete -> "member:delete"
    RoleCreate -> "role:create"
    RoleRead -> "role:read"
    RoleUpdate -> "role:update"
    RoleDelete -> "role:delete"
    SpaceCreate -> "space:create"
    SpaceRead -> "space:read"
    SpaceUpdate -> "space:update"
    SpaceDelete -> "space:delete"
    GuestCreate -> "guest:create"
    GuestRead -> "guest:read"
    GuestUpdate -> "guest:update"
    GuestDelete -> "guest:delete"
  }
}

pub fn from_string(raw: String) -> Result(Permission, Nil) {
  case raw {
    "org:read" -> Ok(OrgRead)
    "org:update" -> Ok(OrgUpdate)
    "org:delete" -> Ok(OrgDelete)
    "member:create" -> Ok(MemberCreate)
    "member:read" -> Ok(MemberRead)
    "member:update" -> Ok(MemberUpdate)
    "member:delete" -> Ok(MemberDelete)
    "role:create" -> Ok(RoleCreate)
    "role:read" -> Ok(RoleRead)
    "role:update" -> Ok(RoleUpdate)
    "role:delete" -> Ok(RoleDelete)
    "space:create" -> Ok(SpaceCreate)
    "space:read" -> Ok(SpaceRead)
    "space:update" -> Ok(SpaceUpdate)
    "space:delete" -> Ok(SpaceDelete)
    "guest:create" -> Ok(GuestCreate)
    "guest:read" -> Ok(GuestRead)
    "guest:update" -> Ok(GuestUpdate)
    "guest:delete" -> Ok(GuestDelete)
    _ -> Error(Nil)
  }
}
