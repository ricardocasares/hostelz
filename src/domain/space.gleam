import domain/organization.{type OrganizationId}
import gleam/option.{type Option}
import gleam/string

pub opaque type SpaceId {
  SpaceId(value: String)
}

/// A space is either an atomic sleepable unit (a leaf — bed, bunk, pod, a
/// private room booked as one) or a grouping that contains other spaces (room,
/// dorm, cabin, hostel, ...). Both carry an open-ended label; the type axis is
/// leaf-vs-container. Any space is bookable.
pub type Kind {
  Unit(label: String)
  Grouping(label: String)
}

pub opaque type Space {
  Space(
    id: SpaceId,
    organization_id: OrganizationId,
    parent_id: Option(SpaceId),
    kind: Kind,
    name: String,
    bookable: Bool,
  )
}

pub type SpaceError {
  EmptyId
  EmptyName
  EmptyLabel
}

pub fn new_id(raw: String) -> Result(SpaceId, SpaceError) {
  let raw = string.trim(raw)
  case string.is_empty(raw) {
    True -> Error(EmptyId)
    False -> Ok(SpaceId(raw))
  }
}

pub fn unit(label: String) -> Result(Kind, SpaceError) {
  case string.trim(label) {
    "" -> Error(EmptyLabel)
    trimmed -> Ok(Unit(trimmed))
  }
}

pub fn grouping(label: String) -> Result(Kind, SpaceError) {
  case string.trim(label) {
    "" -> Error(EmptyLabel)
    trimmed -> Ok(Grouping(trimmed))
  }
}

pub fn new(
  id: SpaceId,
  organization_id: OrganizationId,
  parent_id: Option(SpaceId),
  kind: Kind,
  name: String,
  bookable: Bool,
) -> Result(Space, SpaceError) {
  case string.trim(name) {
    "" -> Error(EmptyName)
    trimmed ->
      Ok(Space(id, organization_id, parent_id, kind, trimmed, bookable))
  }
}

/// The sensible default bookability for a new space: units are bookable, a
/// grouping is not (an owner opts a grouping in to sell it as a whole).
pub fn default_bookable(kind: Kind) -> Bool {
  case kind {
    Unit(_) -> True
    Grouping(_) -> False
  }
}

// accessors
pub fn id(space: Space) -> SpaceId {
  space.id
}

pub fn space_id(id: SpaceId) -> String {
  id.value
}

pub fn organization_id(space: Space) -> OrganizationId {
  space.organization_id
}

pub fn parent_id(space: Space) -> Option(SpaceId) {
  space.parent_id
}

pub fn kind(space: Space) -> Kind {
  space.kind
}

pub fn name(space: Space) -> String {
  space.name
}

pub fn is_bookable(space: Space) -> Bool {
  space.bookable
}

pub fn set_bookable(space: Space, bookable: Bool) -> Space {
  Space(..space, bookable:)
}

pub fn kind_label(kind: Kind) -> String {
  case kind {
    Unit(label) -> label
    Grouping(label) -> label
  }
}

pub fn kind_is_grouping(kind: Kind) -> Bool {
  case kind {
    Unit(_) -> False
    Grouping(_) -> True
  }
}

/// Whether `parent` may contain children — only groupings can. The leaf
/// invariant ("a unit never gets children") is applied by the create use case,
/// which is the only place that knows the parent's kind.
pub fn can_contain(parent: Space) -> Bool {
  kind_is_grouping(parent.kind)
}

// state transitions return new immutable values (same identity)
pub fn rename(space: Space, new_name: String) -> Result(Space, SpaceError) {
  new(
    space.id,
    space.organization_id,
    space.parent_id,
    space.kind,
    new_name,
    space.bookable,
  )
}

pub fn reparent(space: Space, new_parent: Option(SpaceId)) -> Space {
  Space(..space, parent_id: new_parent)
}

// identity equality — two spaces are "the same" iff their ids match
pub fn same_space(a: Space, b: Space) -> Bool {
  a.id == b.id
}
