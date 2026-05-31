//// Unit tests for the organization adapter's `reconstruct` — the re-validation
//// that turns a bad stored row into a `Corrupt` error. Pure, no database.

import db/organization_repo
import domain/organization
import domain/organization_repo as port
import domain/slug

pub fn reconstruct_valid_row_test() {
  let assert Ok(o) =
    organization_repo.reconstruct("org_1", "backpackers", "Backpackers")
  assert organization.name(o) == "Backpackers"
  assert slug.to_string(organization.slug(o)) == "backpackers"
}

pub fn reconstruct_empty_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    organization_repo.reconstruct("", "backpackers", "Backpackers")
}

pub fn reconstruct_bad_slug_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    organization_repo.reconstruct("org_1", "Bad Slug", "Backpackers")
}

pub fn reconstruct_empty_name_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    organization_repo.reconstruct("org_1", "backpackers", "  ")
}
