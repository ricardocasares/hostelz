import client/route
import gleam/uri
import gleeunit/should

fn parse(path: String) -> uri.Uri {
  let assert Ok(uri) = uri.parse("http://localhost" <> path)
  uri
}

pub fn root_is_dashboard_test() {
  route.from_uri(parse("/")) |> should.equal(route.Dashboard)
}

pub fn login_path_test() {
  route.from_uri(parse("/login")) |> should.equal(route.Login)
}

pub fn signup_path_test() {
  route.from_uri(parse("/signup")) |> should.equal(route.Signup)
}

pub fn orgs_path_is_dashboard_test() {
  route.from_uri(parse("/orgs")) |> should.equal(route.Dashboard)
}

pub fn unknown_path_is_not_found_test() {
  route.from_uri(parse("/nope")) |> should.equal(route.NotFound)
}

pub fn to_path_round_trips_test() {
  route.to_path(route.Login) |> should.equal("/login")
  route.to_path(route.Signup) |> should.equal("/signup")
  route.to_path(route.Dashboard) |> should.equal("/")
  route.from_uri(parse(route.to_path(route.Login))) |> should.equal(route.Login)
  route.from_uri(parse(route.to_path(route.Signup)))
  |> should.equal(route.Signup)
  route.from_uri(parse(route.to_path(route.Dashboard)))
  |> should.equal(route.Dashboard)
}
