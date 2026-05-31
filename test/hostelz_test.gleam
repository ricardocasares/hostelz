import gleam/option
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn some_test() {
  let a = option.unwrap(option.Some(1), 3)
  assert a == 1
}
