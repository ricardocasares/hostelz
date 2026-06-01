//// Client-side routes. `from_uri` maps a browser URL to a `Route`; `to_path`
//// renders one back to a path for `modem.push`.

import gleam/uri.{type Uri}

pub type Route {
  Login
  Signup
  Dashboard
  NotFound
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] -> Dashboard
    ["login"] -> Login
    ["signup"] -> Signup
    ["orgs"] -> Dashboard
    _ -> NotFound
  }
}

pub fn to_path(route: Route) -> String {
  case route {
    Login -> "/login"
    Signup -> "/signup"
    Dashboard -> "/"
    NotFound -> "/404"
  }
}
