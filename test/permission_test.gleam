import domain/permission
import gleam/list

pub fn catalog_round_trips_test() {
  list.each(permission.catalog, fn(p) {
    assert permission.from_string(permission.to_string(p)) == Ok(p)
  })
}

pub fn unknown_permission_is_error_test() {
  assert permission.from_string("nope:nope") == Error(Nil)
}

pub fn catalog_is_non_empty_test() {
  assert permission.catalog != []
}
