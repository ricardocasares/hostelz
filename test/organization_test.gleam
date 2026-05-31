import domain/organization
import domain/slug

fn a_slug() -> slug.Slug {
  let assert Ok(s) = slug.new("backpackers")
  s
}

pub fn new_id_rejects_empty_test() {
  assert organization.new_id("") == Error(organization.EmptyId)
}

pub fn new_id_trims_test() {
  let assert Ok(id) = organization.new_id("  org_1  ")
  assert organization.organization_id(id) == "org_1"
}

pub fn new_org_is_accepted_test() {
  let assert Ok(id) = organization.new_id("org_1")
  let assert Ok(o) = organization.new(id, a_slug(), "Backpackers")
  assert organization.name(o) == "Backpackers"
  assert slug.to_string(organization.slug(o)) == "backpackers"
}

pub fn new_org_trims_name_test() {
  let assert Ok(id) = organization.new_id("org_1")
  let assert Ok(o) = organization.new(id, a_slug(), "  Backpackers  ")
  assert organization.name(o) == "Backpackers"
}

pub fn empty_name_is_rejected_test() {
  let assert Ok(id) = organization.new_id("org_1")
  assert organization.new(id, a_slug(), "  ") == Error(organization.EmptyName)
}

pub fn rename_updates_name_test() {
  let assert Ok(id) = organization.new_id("org_1")
  let assert Ok(o) = organization.new(id, a_slug(), "Backpackers")
  let assert Ok(renamed) = organization.rename(o, "Backpackers HQ")
  assert organization.name(renamed) == "Backpackers HQ"
}

pub fn same_organization_compares_by_id_test() {
  let assert Ok(id) = organization.new_id("org_1")
  let assert Ok(a) = organization.new(id, a_slug(), "A")
  let assert Ok(b) = organization.new(id, a_slug(), "B")
  assert organization.same_organization(a, b)
}
