import domain/organization
import domain/space
import gleam/option.{None, Some}

fn an_org_id() -> organization.OrganizationId {
  let assert Ok(id) = organization.new_id("org_1")
  id
}

fn a_grouping() -> space.Kind {
  let assert Ok(k) = space.grouping("hostel")
  k
}

fn a_unit() -> space.Kind {
  let assert Ok(k) = space.unit("bed")
  k
}

// --- SpaceId ---

pub fn new_id_rejects_empty_test() {
  assert space.new_id("") == Error(space.EmptyId)
}

pub fn new_id_trims_test() {
  let assert Ok(id) = space.new_id("  sp_1  ")
  assert space.space_id(id) == "sp_1"
}

// --- Kind ---

pub fn unit_rejects_empty_label_test() {
  assert space.unit("  ") == Error(space.EmptyLabel)
}

pub fn grouping_rejects_empty_label_test() {
  assert space.grouping("") == Error(space.EmptyLabel)
}

pub fn unit_is_not_a_grouping_test() {
  let assert Ok(k) = space.unit("bunk")
  assert space.kind_is_grouping(k) == False
  assert space.kind_label(k) == "bunk"
}

pub fn grouping_is_a_grouping_test() {
  let assert Ok(k) = space.grouping("room")
  assert space.kind_is_grouping(k) == True
  assert space.kind_label(k) == "room"
}

// --- construction ---

pub fn new_root_space_is_accepted_test() {
  let assert Ok(id) = space.new_id("sp_1")
  let assert Ok(s) =
    space.new(id, an_org_id(), None, a_grouping(), "Main Hostel")
  assert space.name(s) == "Main Hostel"
  assert space.parent_id(s) == None
}

pub fn new_space_trims_name_test() {
  let assert Ok(id) = space.new_id("sp_1")
  let assert Ok(s) = space.new(id, an_org_id(), None, a_grouping(), "  Main  ")
  assert space.name(s) == "Main"
}

pub fn empty_name_is_rejected_test() {
  let assert Ok(id) = space.new_id("sp_1")
  assert space.new(id, an_org_id(), None, a_grouping(), "  ")
    == Error(space.EmptyName)
}

pub fn nested_space_keeps_its_parent_test() {
  let assert Ok(pid) = space.new_id("sp_parent")
  let assert Ok(id) = space.new_id("sp_child")
  let assert Ok(s) = space.new(id, an_org_id(), Some(pid), a_unit(), "Bed 1")
  assert space.parent_id(s) == Some(pid)
}

// --- leaf invariant ---

pub fn only_groupings_can_contain_children_test() {
  let assert Ok(g_id) = space.new_id("sp_g")
  let assert Ok(grouping) =
    space.new(g_id, an_org_id(), None, a_grouping(), "Room")
  let assert Ok(u_id) = space.new_id("sp_u")
  let assert Ok(unit) = space.new(u_id, an_org_id(), None, a_unit(), "Bed")
  assert space.can_contain(grouping) == True
  assert space.can_contain(unit) == False
}

// --- transitions ---

pub fn rename_revalidates_name_test() {
  let assert Ok(id) = space.new_id("sp_1")
  let assert Ok(s) = space.new(id, an_org_id(), None, a_grouping(), "Room")
  assert space.rename(s, "  ") == Error(space.EmptyName)
  let assert Ok(renamed) = space.rename(s, "Room A")
  assert space.name(renamed) == "Room A"
}

pub fn reparent_sets_parent_and_keeps_identity_test() {
  let assert Ok(id) = space.new_id("sp_1")
  let assert Ok(s) = space.new(id, an_org_id(), None, a_grouping(), "Room")
  let assert Ok(pid) = space.new_id("sp_parent")
  let moved = space.reparent(s, Some(pid))
  assert space.parent_id(moved) == Some(pid)
  assert space.same_space(s, moved)
}

// --- identity ---

pub fn same_space_compares_by_id_test() {
  let assert Ok(id) = space.new_id("sp_1")
  let assert Ok(a) = space.new(id, an_org_id(), None, a_grouping(), "A")
  let assert Ok(b) = space.new(id, an_org_id(), None, a_unit(), "B")
  assert space.same_space(a, b)
}
