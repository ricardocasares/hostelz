//// Unit tests for the space adapter's `reconstruct` — re-validation of stored
//// rows, including the nullable `parent_id`, the unit/grouping flag, and the
//// `bookable` flag. Pure, no database.

import db/space_repo
import domain/repo_error as port
import domain/space
import gleam/option.{None, Some}

pub fn reconstruct_valid_root_grouping_test() {
  let assert Ok(s) =
    space_repo.reconstruct("sp_1", "org_1", None, True, "hostel", "Main", False)
  assert space.name(s) == "Main"
  assert space.parent_id(s) == None
  assert space.kind_is_grouping(space.kind(s)) == True
  assert space.kind_label(space.kind(s)) == "hostel"
  assert space.is_bookable(s) == False
}

pub fn reconstruct_valid_child_unit_test() {
  let assert Ok(s) =
    space_repo.reconstruct(
      "sp_2",
      "org_1",
      Some("sp_1"),
      False,
      "bed",
      "Bed 1",
      True,
    )
  let assert Ok(pid) = space.new_id("sp_1")
  assert space.parent_id(s) == Some(pid)
  assert space.kind_is_grouping(space.kind(s)) == False
  assert space.is_bookable(s) == True
}

pub fn reconstruct_empty_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    space_repo.reconstruct("", "org_1", None, True, "hostel", "Main", False)
}

pub fn reconstruct_empty_org_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    space_repo.reconstruct("sp_1", "", None, True, "hostel", "Main", False)
}

pub fn reconstruct_empty_parent_id_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    space_repo.reconstruct("sp_1", "org_1", Some(""), False, "bed", "Bed", True)
}

pub fn reconstruct_empty_label_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    space_repo.reconstruct("sp_1", "org_1", None, True, "", "Main", False)
}

pub fn reconstruct_empty_name_is_corrupt_test() {
  let assert Error(port.Corrupt(_)) =
    space_repo.reconstruct("sp_1", "org_1", None, True, "hostel", "  ", False)
}
