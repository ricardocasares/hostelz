import auth/token

pub fn hash_is_deterministic_test() {
  assert token.hash("abc") == token.hash("abc")
}

pub fn hash_differs_per_input_test() {
  assert token.hash("abc") != token.hash("abd")
}

pub fn hash_is_not_the_raw_token_test() {
  assert token.hash("secret") != "secret"
}
