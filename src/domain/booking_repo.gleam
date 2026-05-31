//// The persistence *port* for bookings: a record of functions the application
//// depends on, with no knowledge of storage. The adapter (`db/booking_repo`)
//// owns the oversell guard — `create` and `assign_item` run under a per-org
//// advisory lock, counting demand against capacity — and surfaces a conflict as
//// `BookingConflict` rather than a raw storage error.

import domain/booking.{type Booking, type BookingId}
import domain/booking_item.{type BookingItem, type BookingItemId}
import domain/organization.{type OrganizationId}
import domain/period.{type Period}
import domain/repo_error.{type RepoError}
import domain/space.{type SpaceId}
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option}

/// A one-level room-type with its bookable capacity (bookable leaf children).
pub type RoomType {
  RoomType(id: SpaceId, name: String, label: String, capacity: Int)
}

/// Why a booking write was refused.
pub type BookingConflict {
  /// A pinned space is already taken for an overlapping period.
  Unavailable
  /// The room-type is full for the period (capacity would be exceeded).
  OverCapacity(room_type: String)
  /// An unassigned hold targeted a space that is not a one-level room-type.
  NotARoomType(target: String)
  /// A plain storage failure.
  Storage(RepoError)
}

pub type BookingRepo {
  BookingRepo(
    /// Persist a booking and its items atomically under the capacity guard.
    create: fn(Booking, List(BookingItem)) ->
      Promise(Result(Nil, BookingConflict)),
    find: fn(BookingId) -> Promise(Result(Booking, RepoError)),
    list_items: fn(BookingId) -> Promise(Result(List(BookingItem), RepoError)),
    list_by_organization: fn(OrganizationId) ->
      Promise(Result(List(Booking), RepoError)),
    /// Update status; when `frees` is true, also delete the booking's demand.
    apply_transition: fn(Booking, Bool) -> Promise(Result(Nil, RepoError)),
    /// Pin a free bed to an unassigned item (at check-in).
    assign_item: fn(BookingItemId, SpaceId) ->
      Promise(Result(Nil, BookingConflict)),
    /// Bookable beds left in a room-type over a period.
    beds_left: fn(SpaceId, Period) -> Promise(Result(Int, RepoError)),
    /// A free bookable bed in a room-type for a period, if any.
    find_free_unit: fn(SpaceId, Period) ->
      Promise(Result(Option(SpaceId), RepoError)),
    list_room_types: fn(OrganizationId) ->
      Promise(Result(List(RoomType), RepoError)),
    /// Whether a space's subtree carries any active booking demand.
    space_has_active_demand: fn(SpaceId) -> Promise(Result(Bool, RepoError)),
  )
}
