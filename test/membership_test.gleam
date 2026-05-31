import domain/membership
import domain/organization
import domain/role
import domain/user

pub fn new_id_rejects_empty_test() {
  assert membership.new_id("") == Error(membership.EmptyId)
}

pub fn assign_role_changes_role_keeps_identity_test() {
  let assert Ok(mid) = membership.new_id("m1")
  let assert Ok(oid) = organization.new_id("o1")
  let assert Ok(uid) = user.new_id("u1")
  let assert Ok(rid1) = role.new_id("r1")
  let assert Ok(rid2) = role.new_id("r2")
  let m = membership.new(mid, oid, uid, rid1)
  let reassigned = membership.assign_role(m, rid2)
  assert membership.role_id(reassigned) == rid2
  assert membership.id(reassigned) == membership.id(m)
}
