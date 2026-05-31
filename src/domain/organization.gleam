import domain/slug.{type Slug}
import gleam/string

pub opaque type OrganizationId {
  OrganizationId(value: String)
}

pub opaque type Organization {
  Organization(id: OrganizationId, slug: Slug, name: String)
}

pub type OrganizationError {
  EmptyId
  EmptyName
}

pub fn new_id(raw: String) -> Result(OrganizationId, OrganizationError) {
  let raw = string.trim(raw)
  case string.is_empty(raw) {
    True -> Error(EmptyId)
    False -> Ok(OrganizationId(raw))
  }
}

pub fn new(
  id: OrganizationId,
  slug: Slug,
  name: String,
) -> Result(Organization, OrganizationError) {
  case string.trim(name) {
    "" -> Error(EmptyName)
    trimmed -> Ok(Organization(id, slug, trimmed))
  }
}

// accessors
pub fn id(org: Organization) -> OrganizationId {
  org.id
}

pub fn organization_id(id: OrganizationId) -> String {
  id.value
}

pub fn slug(org: Organization) -> Slug {
  org.slug
}

pub fn name(org: Organization) -> String {
  org.name
}

// state transitions return new immutable values (same identity)
pub fn rename(
  org: Organization,
  new_name: String,
) -> Result(Organization, OrganizationError) {
  new(org.id, org.slug, new_name)
}

// identity equality — two organizations are "the same" iff their ids match
pub fn same_organization(a: Organization, b: Organization) -> Bool {
  a.id == b.id
}
