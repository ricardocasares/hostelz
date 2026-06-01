//// The hostelz SPA — a Lustre (Elm-style) client.
////
//// First slice: sign in, persist the bearer token, resolve it to the current
//// user, and list the user's organizations. Routing is real-URL via `modem`;
//// API data is decoded into the server's opaque domain types (see
//// `client/decode`).

import client/api
import client/route.{
  type Route, Dashboard, Login, NotFound, Signup, from_uri, to_path,
}
import client/storage
import domain/organization.{type Organization}
import domain/slug
import domain/user.{type User}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

// --- Model -----------------------------------------------------------------

/// The session lifecycle. `TokenOnly` is the brief boot state where a token was
/// restored from storage but `GET /auth/me` hasn't resolved it to a user yet.
type Auth {
  Anonymous
  TokenOnly(token: String)
  Authenticated(token: String, user: User)
}

type Remote(a) {
  NotAsked
  Loading
  Loaded(a)
  Failed(String)
}

type Model {
  Model(
    route: Route,
    auth: Auth,
    name: String,
    email: String,
    password: String,
    error: Option(String),
    orgs: Remote(List(Organization)),
  )
}

type Msg {
  UserNavigated(Route)
  NameChanged(String)
  EmailChanged(String)
  PasswordChanged(String)
  LoginSubmitted
  LoginResponded(Result(#(String, User), api.ApiError))
  SignupSubmitted
  SignupResponded(Result(User, api.ApiError))
  MeResponded(Result(User, api.ApiError))
  OrgsResponded(Result(List(Organization), api.ApiError))
  LogoutClicked
  LogoutResponded(Result(Nil, api.ApiError))
}

fn init(_flags) -> #(Model, Effect(Msg)) {
  let route = case modem.initial_uri() {
    Ok(uri) -> from_uri(uri)
    Error(_) -> Dashboard
  }
  let #(auth, boot) = case storage.read_token() {
    Ok(token) -> #(TokenOnly(token), api.me(token, MeResponded))
    Error(_) -> #(Anonymous, effect.none())
  }
  let model =
    Model(
      route:,
      auth:,
      name: "",
      email: "",
      password: "",
      error: None,
      orgs: NotAsked,
    )
  let #(model, guard) = sync(model)
  let listen = modem.init(fn(uri) { UserNavigated(from_uri(uri)) })
  #(model, effect.batch([listen, boot, guard]))
}

// --- Update ----------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // Clear any form error when moving between pages, then run route guards.
    UserNavigated(route) -> sync(Model(..model, route:, error: None))

    NameChanged(name) -> #(Model(..model, name:), effect.none())
    EmailChanged(email) -> #(Model(..model, email:), effect.none())
    PasswordChanged(password) -> #(Model(..model, password:), effect.none())

    LoginSubmitted -> #(
      Model(..model, error: None),
      api.login(model.email, model.password, LoginResponded),
    )

    LoginResponded(Ok(#(token, user))) -> {
      storage.write_token(token)
      let model =
        Model(
          ..model,
          auth: Authenticated(token, user),
          name: "",
          password: "",
          error: None,
        )
      #(model, modem.push("/", None, None))
    }
    LoginResponded(Error(error)) -> #(
      Model(..model, error: Some(error_text(error))),
      effect.none(),
    )

    SignupSubmitted -> #(
      Model(..model, error: None),
      api.register(model.name, model.email, model.password, SignupResponded),
    )

    // Registration doesn't return a token, so log in with the same credentials
    // to land an authenticated session — reusing the `LoginResponded` path.
    SignupResponded(Ok(_user)) -> #(
      model,
      api.login(model.email, model.password, LoginResponded),
    )
    SignupResponded(Error(error)) -> #(
      Model(..model, error: Some(error_text(error))),
      effect.none(),
    )

    MeResponded(Ok(user)) ->
      sync(Model(..model, auth: Authenticated(token_of(model.auth), user)))
    MeResponded(Error(_)) -> {
      storage.clear_token()
      sync(Model(..model, auth: Anonymous))
    }

    OrgsResponded(Ok(orgs)) -> #(
      Model(..model, orgs: Loaded(orgs)),
      effect.none(),
    )
    OrgsResponded(Error(api.Unauthorized)) -> {
      storage.clear_token()
      sync(Model(..model, auth: Anonymous, orgs: NotAsked))
    }
    OrgsResponded(Error(error)) -> #(
      Model(..model, orgs: Failed(error_text(error))),
      effect.none(),
    )

    LogoutClicked -> #(model, api.logout(token_of(model.auth), LogoutResponded))
    LogoutResponded(_) -> {
      storage.clear_token()
      #(
        Model(..model, auth: Anonymous, orgs: NotAsked),
        modem.push("/login", None, None),
      )
    }
  }
}

/// Enforce route guards and trigger the data each authenticated page needs.
/// Called after any navigation or auth change so the two stay consistent.
fn sync(model: Model) -> #(Model, Effect(Msg)) {
  case model.route, model.auth {
    // Still booting: wait for `GET /auth/me` before deciding anything.
    _, TokenOnly(_) -> #(model, effect.none())

    Dashboard, Authenticated(token, _) ->
      case model.orgs {
        NotAsked -> #(
          Model(..model, orgs: Loading),
          api.list_organizations(token, OrgsResponded),
        )
        _ -> #(model, effect.none())
      }
    Dashboard, Anonymous -> redirect(model, Login)

    Login, Authenticated(_, _) -> redirect(model, Dashboard)
    Login, Anonymous -> #(model, effect.none())

    Signup, Authenticated(_, _) -> redirect(model, Dashboard)
    Signup, Anonymous -> #(model, effect.none())

    NotFound, _ -> #(model, effect.none())
  }
}

/// Send the user to `to`. We set `route` on the model directly — not just via
/// `modem` — so the view changes immediately even during `init`, before modem's
/// link listener is live to round-trip a `push` back as `UserNavigated`
/// (otherwise the redirect message is dropped and the page hangs). `replace`
/// then aligns the URL bar without leaving the guarded path in history. We
/// re-run `sync` at the destination so its own guard/data effects fire.
fn redirect(model: Model, to: Route) -> #(Model, Effect(Msg)) {
  let #(model, next) = sync(Model(..model, route: to))
  #(model, effect.batch([modem.replace(to_path(to), None, None), next]))
}

fn token_of(auth: Auth) -> String {
  case auth {
    Anonymous -> ""
    TokenOnly(token) -> token
    Authenticated(token, _) -> token
  }
}

fn error_text(error: api.ApiError) -> String {
  case error {
    api.Network -> "Network error — check your connection."
    api.Unauthorized -> "Invalid email or password."
    api.Rejected(message) -> message
    api.ServerError(status) -> "Server error (" <> int.to_string(status) <> ")."
    api.BadResponse -> "Unexpected response from the server."
  }
}

// --- View ------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model.route, model.auth {
    _, TokenOnly(_) -> splash("Loading…")
    Login, _ -> login_view(model)
    Signup, _ -> signup_view(model)
    Dashboard, Authenticated(_, user) -> dashboard_view(user, model.orgs)
    Dashboard, _ -> splash("Redirecting…")
    NotFound, _ -> splash("Page not found.")
  }
}

fn splash(text: String) -> Element(Msg) {
  html.main(
    [attr.class("flex min-h-screen items-center justify-center text-gray-500")],
    [html.text(text)],
  )
}

fn login_view(model: Model) -> Element(Msg) {
  auth_card("Sign in", LoginSubmitted, [
    field("Email", "email", model.email, EmailChanged),
    field("Password", "password", model.password, PasswordChanged),
    error_banner(model.error),
    submit_button("Sign in"),
    auth_switch("Need an account?", "Sign up", "/signup"),
  ])
}

fn signup_view(model: Model) -> Element(Msg) {
  auth_card("Create your account", SignupSubmitted, [
    field("Name", "text", model.name, NameChanged),
    field("Email", "email", model.email, EmailChanged),
    field("Password", "password", model.password, PasswordChanged),
    error_banner(model.error),
    submit_button("Sign up"),
    auth_switch("Already have an account?", "Sign in", "/login"),
  ])
}

/// Shared shell for the login/signup forms: a centred card whose `submit`
/// message is dispatched on form submission.
fn auth_card(
  title: String,
  submit: Msg,
  body: List(Element(Msg)),
) -> Element(Msg) {
  html.main(
    [attr.class("flex min-h-screen items-center justify-center bg-gray-50 p-4")],
    [
      html.form(
        [
          attr.class(
            "w-full max-w-sm space-y-4 rounded-xl bg-white p-8 shadow-sm",
          ),
          event.on_submit(fn(_fields) { submit }),
        ],
        [
          html.h1([attr.class("text-2xl font-semibold text-gray-900")], [
            html.text(title),
          ]),
          ..body
        ],
      ),
    ],
  )
}

fn submit_button(label: String) -> Element(Msg) {
  html.button(
    [
      attr.type_("submit"),
      attr.class(
        "w-full rounded-lg bg-gray-900 px-4 py-2 font-medium text-white hover:bg-gray-800",
      ),
    ],
    [html.text(label)],
  )
}

/// A prompt with an internal link to the other auth page. `modem` intercepts the
/// link, so navigation flows through `UserNavigated` without a custom handler.
fn auth_switch(prompt: String, label: String, path: String) -> Element(Msg) {
  html.p([attr.class("text-center text-sm text-gray-500")], [
    html.text(prompt <> " "),
    html.a(
      [attr.href(path), attr.class("font-medium text-gray-900 hover:underline")],
      [html.text(label)],
    ),
  ])
}

fn field(
  label: String,
  kind: String,
  value: String,
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attr.class("block space-y-1")], [
    html.span([attr.class("text-sm font-medium text-gray-700")], [
      html.text(label),
    ]),
    html.input([
      attr.type_(kind),
      attr.value(value),
      event.on_input(on_change),
      attr.class(
        "w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-gray-900 focus:outline-none",
      ),
    ]),
  ])
}

fn error_banner(error: Option(String)) -> Element(Msg) {
  case error {
    None -> element.none()
    Some(message) ->
      html.p(
        [attr.class("rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700")],
        [html.text(message)],
      )
  }
}

fn dashboard_view(u: User, orgs: Remote(List(Organization))) -> Element(Msg) {
  html.div([attr.class("min-h-screen bg-gray-50")], [
    html.header(
      [
        attr.class(
          "flex items-center justify-between border-b border-gray-200 bg-white px-6 py-4",
        ),
      ],
      [
        html.h1([attr.class("text-lg font-semibold text-gray-900")], [
          html.text("hostelz"),
        ]),
        html.div([attr.class("flex items-center gap-4")], [
          html.span([attr.class("text-sm text-gray-600")], [
            html.text(user.name(u)),
          ]),
          html.button(
            [
              event.on_click(LogoutClicked),
              attr.class(
                "rounded-lg border border-gray-300 px-3 py-1 text-sm hover:bg-gray-100",
              ),
            ],
            [html.text("Log out")],
          ),
        ]),
      ],
    ),
    html.main([attr.class("mx-auto max-w-3xl p-6")], [
      html.h2([attr.class("mb-4 text-xl font-semibold text-gray-900")], [
        html.text("Your organizations"),
      ]),
      orgs_view(orgs),
    ]),
  ])
}

fn orgs_view(orgs: Remote(List(Organization))) -> Element(Msg) {
  case orgs {
    NotAsked -> element.none()
    Loading -> html.p([attr.class("text-gray-500")], [html.text("Loading…")])
    Failed(message) ->
      html.p([attr.class("text-red-600")], [html.text(message)])
    Loaded([]) ->
      html.p([attr.class("text-gray-500")], [html.text("No organizations yet.")])
    Loaded(items) ->
      html.ul([attr.class("space-y-2")], list.map(items, org_row))
  }
}

fn org_row(o: Organization) -> Element(Msg) {
  html.li([attr.class("rounded-lg border border-gray-200 bg-white px-4 py-3")], [
    html.div([attr.class("font-medium text-gray-900")], [
      html.text(organization.name(o)),
    ]),
    html.div([attr.class("text-sm text-gray-500")], [
      html.text(slug.to_string(organization.slug(o))),
    ]),
  ])
}
