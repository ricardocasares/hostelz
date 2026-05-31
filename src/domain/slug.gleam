import gleam/list
import gleam/string

pub opaque type Slug {
  Slug(value: String)
}

pub type SlugError {
  Empty
  Invalid
}

const allowed = "abcdefghijklmnopqrstuvwxyz0123456789-"

pub fn new(raw: String) -> Result(Slug, SlugError) {
  let trimmed = string.trim(raw)
  case trimmed {
    "" -> Error(Empty)
    _ ->
      case is_valid(trimmed) {
        True -> Ok(Slug(trimmed))
        False -> Error(Invalid)
      }
  }
}

pub fn to_string(slug: Slug) -> String {
  slug.value
}

// lowercase alphanumerics joined by single hyphens, e.g. "backpackers-hostel"
fn is_valid(value: String) -> Bool {
  list.all(string.to_graphemes(value), fn(c) { string.contains(allowed, c) })
  && !string.starts_with(value, "-")
  && !string.ends_with(value, "-")
  && !string.contains(value, "--")
}
