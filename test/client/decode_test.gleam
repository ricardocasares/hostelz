import client/decode
import gleam/json
import gleeunit/should

const user_json = "{\"id\":\"u1\",\"email\":\"ann@example.com\",\"name\":\"Ann\"}"

pub fn user_decodes_to_domain_test() {
  let assert Ok(raw) = json.parse(user_json, decode.user_decoder())
  decode.to_user(raw) |> should.be_ok
}

pub fn session_decodes_token_and_user_test() {
  let body = "{\"token\":\"tok-123\",\"user\":" <> user_json <> "}"
  let assert Ok(#(token, raw)) = json.parse(body, decode.session_decoder())
  token |> should.equal("tok-123")
  decode.to_user(raw) |> should.be_ok
}

pub fn organizations_decode_to_domain_test() {
  let body = "[{\"id\":\"o1\",\"slug\":\"my-hostel\",\"name\":\"My Hostel\"}]"
  let assert Ok(raws) = json.parse(body, decode.orgs_decoder())
  decode.to_orgs(raws) |> should.be_ok
}

pub fn invalid_email_fails_conversion_test() {
  let body = "{\"id\":\"u1\",\"email\":\"not-an-email\",\"name\":\"Ann\"}"
  let assert Ok(raw) = json.parse(body, decode.user_decoder())
  decode.to_user(raw) |> should.be_error
}

pub fn invalid_slug_fails_conversion_test() {
  let body = "{\"id\":\"o1\",\"slug\":\"Not A Slug!\",\"name\":\"X\"}"
  let assert Ok(raw) = json.parse(body, decode.org_decoder())
  decode.to_org(raw) |> should.be_error
}
