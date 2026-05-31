import domain/slug

pub fn accepts_simple_test() {
  let assert Ok(s) = slug.new("backpackers")
  assert slug.to_string(s) == "backpackers"
}

pub fn accepts_hyphens_and_digits_test() {
  let assert Ok(s) = slug.new("backpackers-hostel-2")
  assert slug.to_string(s) == "backpackers-hostel-2"
}

pub fn trims_test() {
  let assert Ok(s) = slug.new("  backpackers  ")
  assert slug.to_string(s) == "backpackers"
}

pub fn rejects_empty_test() {
  assert slug.new("") == Error(slug.Empty)
}

pub fn rejects_whitespace_test() {
  assert slug.new("   ") == Error(slug.Empty)
}

pub fn rejects_uppercase_test() {
  assert slug.new("Backpackers") == Error(slug.Invalid)
}

pub fn rejects_spaces_test() {
  assert slug.new("back packers") == Error(slug.Invalid)
}

pub fn rejects_leading_hyphen_test() {
  assert slug.new("-backpackers") == Error(slug.Invalid)
}

pub fn rejects_trailing_hyphen_test() {
  assert slug.new("backpackers-") == Error(slug.Invalid)
}

pub fn rejects_double_hyphen_test() {
  assert slug.new("back--packers") == Error(slug.Invalid)
}

pub fn rejects_punctuation_test() {
  assert slug.new("back_packers!") == Error(slug.Invalid)
}
