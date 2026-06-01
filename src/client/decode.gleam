//// Decoding API responses into the server's opaque domain types.
////
//// The domain types are opaque and their constructors are fallible, so a
//// `decode.Decoder` can't build a fallback value for `decode.failure`. We
//// therefore decode into raw `String` records first, then run the smart
//// constructors (`to_user`/`to_org`). Server data is already valid, so a
//// conversion failure means a corrupt response — the API client surfaces it as
//// `BadResponse`.

import domain/email
import domain/organization.{type Organization}
import domain/slug
import domain/user.{type User}
import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/result

pub type RawUser {
  RawUser(id: String, email: String, name: String)
}

pub type RawOrg {
  RawOrg(id: String, slug: String, name: String)
}

pub fn user_decoder() -> Decoder(RawUser) {
  use id <- decode.field("id", decode.string)
  use email <- decode.field("email", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(RawUser(id:, email:, name:))
}

/// `{ "token": ..., "user": { ... } }` as returned by `POST /auth/login`.
pub fn session_decoder() -> Decoder(#(String, RawUser)) {
  use token <- decode.field("token", decode.string)
  use user <- decode.field("user", user_decoder())
  decode.success(#(token, user))
}

pub fn org_decoder() -> Decoder(RawOrg) {
  use id <- decode.field("id", decode.string)
  use slug <- decode.field("slug", decode.string)
  use name <- decode.field("name", decode.string)
  decode.success(RawOrg(id:, slug:, name:))
}

pub fn orgs_decoder() -> Decoder(List(RawOrg)) {
  decode.list(org_decoder())
}

pub fn to_user(raw: RawUser) -> Result(User, Nil) {
  use id <- result.try(user.new_id(raw.id) |> result.replace_error(Nil))
  use address <- result.try(email.new(raw.email) |> result.replace_error(Nil))
  user.new(id, address, raw.name) |> result.replace_error(Nil)
}

pub fn to_org(raw: RawOrg) -> Result(Organization, Nil) {
  use id <- result.try(organization.new_id(raw.id) |> result.replace_error(Nil))
  use slug <- result.try(slug.new(raw.slug) |> result.replace_error(Nil))
  organization.new(id, slug, raw.name) |> result.replace_error(Nil)
}

pub fn to_orgs(raws: List(RawOrg)) -> Result(List(Organization), Nil) {
  list.try_map(raws, to_org)
}
