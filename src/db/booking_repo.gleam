//// Postgres-backed adapter for the booking persistence port.
////
//// `create` and the status/assignment writes run in a transaction that first
//// takes a per-org advisory lock (`pg_advisory_xact_lock`), so the oversell
//// guard — counting demand against capacity per affected room-type — is atomic
//// against other bookings in the same org. Pinned exclusivity is additionally
//// enforced by the partial EXCLUDE on `booking_demand`. Capacity and
//// room-type-validity failures are signalled out of the transaction as tagged
//// `PostgresqlError`s (so the whole booking rolls back) and mapped back to a
//// `BookingConflict`; a pinned overlap arrives as a real `ConstraintViolated`.

import brioche/sql as db
import db/sql as queries
import domain/booking.{type Booking, type BookingId}
import domain/booking_item.{
  type BookingItem, type BookingItemId, UnitInRoomType, WholeSpace,
}
import domain/booking_repo.{
  type BookingConflict, type BookingRepo, type RoomType, BookingRepo,
  NotARoomType, OverCapacity, RoomType, Storage, Unavailable,
}
import domain/guest.{type GuestId}
import domain/organization.{type OrganizationId}
import domain/period.{type Period}
import domain/repo_error.{type RepoError, Corrupt, NotFound, StorageError}
import domain/space.{type SpaceId}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar.{type Date}

pub fn new(conn: db.Connection) -> BookingRepo {
  BookingRepo(
    create: fn(b, items) { create(conn, b, items) },
    find: fn(id) { find(conn, id) },
    list_items: fn(id) { list_items(conn, id) },
    list_by_organization: fn(org) { list_by_organization(conn, org) },
    apply_transition: fn(b, frees) { apply_transition(conn, b, frees) },
    assign_item: fn(item, bed) { assign_item(conn, item, bed) },
    beds_left: fn(rt, p) { beds_left(conn, rt, p) },
    find_free_unit: fn(rt, p) { find_free_unit(conn, rt, p) },
    list_room_types: fn(org) { list_room_types(conn, org) },
    space_has_active_demand: fn(sid) { space_has_active_demand(conn, sid) },
  )
}

// --- create ----------------------------------------------------------------

fn create(
  conn: db.Connection,
  b: Booking,
  items: List(BookingItem),
) -> Promise(Result(Nil, BookingConflict)) {
  use res <- promise.map(
    db.transaction(conn, fn(tx) { create_tx(tx, b, items) }),
  )
  case res {
    Ok(_) -> Ok(Nil)
    Error(db.ConstraintViolated(constraint: "booking_demand_no_overlap", ..)) ->
      Error(Unavailable)
    Error(db.PostgresqlError(name: "hz_over_capacity", message: rt, ..)) ->
      Error(OverCapacity(rt))
    Error(db.PostgresqlError(name: "hz_not_room_type", message: t, ..)) ->
      Error(NotARoomType(t))
    Error(other) -> Error(Storage(storage_error(other)))
  }
}

fn create_tx(
  tx: db.Connection,
  b: Booking,
  items: List(BookingItem),
) -> Promise(Result(Nil, db.SqlError)) {
  let org = organization.organization_id(booking.organization_id(b))
  use _ <- promise.try_await(advisory_lock(tx, org))
  use _ <- promise.try_await(insert_booking_row(tx, b))
  insert_items(tx, items)
}

fn advisory_lock(
  tx: db.Connection,
  org: String,
) -> Promise(Result(Nil, db.SqlError)) {
  use res <- promise.map(
    db.query("select pg_advisory_xact_lock(hashtext($1))")
    |> db.parameter(db.text(org))
    |> db.returning(decode.dynamic)
    |> db.execute(tx),
  )
  result.replace(res, Nil)
}

fn insert_booking_row(
  tx: db.Connection,
  b: Booking,
) -> Promise(Result(Nil, db.SqlError)) {
  let id = booking.booking_id(booking.id(b))
  let org = organization.organization_id(booking.organization_id(b))
  let status = booking.status_to_string(booking.status(b))
  let saved = case booking.guest_id(b) {
    Some(gid) ->
      queries.insert_booking_with_guest(
        tx,
        id,
        org,
        guest.guest_id(gid),
        status,
      )
    None -> queries.insert_booking(tx, id, org, status)
  }
  use res <- promise.map(saved)
  result.replace(res, Nil)
}

fn insert_items(
  tx: db.Connection,
  items: List(BookingItem),
) -> Promise(Result(Nil, db.SqlError)) {
  case items {
    [] -> promise.resolve(Ok(Nil))
    [item, ..rest] -> {
      use _ <- promise.try_await(insert_item(tx, item))
      insert_items(tx, rest)
    }
  }
}

fn insert_item(
  tx: db.Connection,
  item: BookingItem,
) -> Promise(Result(Nil, db.SqlError)) {
  use _ <- promise.try_await(insert_item_row(tx, item))
  use _ <- promise.try_await(validate_target(tx, item))
  use _ <- promise.try_await(insert_demand(tx, item))
  check_capacity(tx, item)
}

fn insert_item_row(
  tx: db.Connection,
  item: BookingItem,
) -> Promise(Result(Nil, db.SqlError)) {
  let id = booking_item.booking_item_id(booking_item.id(item))
  let bid = booking.booking_id(booking_item.booking_id(item))
  let p = booking_item.period(item)
  let ci = period.check_in(p)
  let co = period.check_out(p)
  let kind = booking_item.kind_to_string(booking_item.kind(item))
  let target = space.space_id(booking_item.target(item))
  let saved = case booking_item.assigned(item) {
    Some(bed) ->
      queries.insert_booking_item_assigned(
        tx,
        id,
        bid,
        ci,
        co,
        kind,
        target,
        space.space_id(bed),
      )
    None ->
      queries.insert_booking_item_unassigned(tx, id, bid, ci, co, kind, target)
  }
  use res <- promise.map(saved)
  result.replace(res, Nil)
}

/// Unassigned holds must target a one-level room-type; pinned items need not.
fn validate_target(
  tx: db.Connection,
  item: BookingItem,
) -> Promise(Result(Nil, db.SqlError)) {
  case booking_item.kind(item) {
    WholeSpace(_) -> promise.resolve(Ok(Nil))
    UnitInRoomType(rt) -> {
      let raw = space.space_id(rt)
      use res <- promise.try_await(queries.validate_room_type(tx, raw))
      case one_int(res.rows, fn(r) { r.valid }) {
        1 -> promise.resolve(Ok(Nil))
        _ -> promise.resolve(Error(tagged("hz_not_room_type", raw)))
      }
    }
  }
}

fn insert_demand(
  tx: db.Connection,
  item: BookingItem,
) -> Promise(Result(Nil, db.SqlError)) {
  let id = booking_item.booking_item_id(booking_item.id(item))
  let p = booking_item.period(item)
  let ci = period.check_in(p)
  let co = period.check_out(p)
  let saved = case booking_item.kind(item) {
    WholeSpace(sp) ->
      queries.insert_pin_demand(tx, id, space.space_id(sp), ci, co)
    UnitInRoomType(rt) ->
      queries.insert_hold_demand(tx, id, space.space_id(rt), ci, co)
  }
  use res <- promise.map(saved)
  result.replace(res, Nil)
}

/// After an item's demand is written, every room-type it touched must still
/// satisfy peak demand <= capacity over the item's period.
fn check_capacity(
  tx: db.Connection,
  item: BookingItem,
) -> Promise(Result(Nil, db.SqlError)) {
  let id = booking_item.booking_item_id(booking_item.id(item))
  let p = booking_item.period(item)
  use res <- promise.try_await(queries.item_room_types(tx, id))
  let room_types = list.map(res.rows, fn(r) { r.room_type })
  check_room_types(tx, room_types, period.check_in(p), period.check_out(p))
}

fn check_room_types(
  tx: db.Connection,
  room_types: List(String),
  ci: Date,
  co: Date,
) -> Promise(Result(Nil, db.SqlError)) {
  case room_types {
    [] -> promise.resolve(Ok(Nil))
    [rt, ..rest] -> {
      use _ <- promise.try_await(check_one_room_type(tx, rt, ci, co))
      check_room_types(tx, rest, ci, co)
    }
  }
}

fn check_one_room_type(
  tx: db.Connection,
  rt: String,
  ci: Date,
  co: Date,
) -> Promise(Result(Nil, db.SqlError)) {
  use cap <- promise.try_await(queries.room_type_capacity(tx, rt))
  use peak <- promise.try_await(queries.room_type_peak_demand(tx, rt, ci, co))
  let capacity = one_int(cap.rows, fn(r) { r.capacity })
  let demand = one_int(peak.rows, fn(r) { r.peak })
  case demand <= capacity {
    True -> promise.resolve(Ok(Nil))
    False -> promise.resolve(Error(tagged("hz_over_capacity", rt)))
  }
}

// --- reads & writes ---------------------------------------------------------

fn find(
  conn: db.Connection,
  id: BookingId,
) -> Promise(Result(Booking, RepoError)) {
  use res <- promise.map(queries.find_booking_by_id(
    conn,
    booking.booking_id(id),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Error(NotFound)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      reconstruct_booking(row.id, row.organization_id, row.guest_id, row.status)
  }
}

fn list_by_organization(
  conn: db.Connection,
  org: OrganizationId,
) -> Promise(Result(List(Booking), RepoError)) {
  use res <- promise.map(queries.list_bookings_by_organization(
    conn,
    organization.organization_id(org),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) {
        reconstruct_booking(
          row.id,
          row.organization_id,
          row.guest_id,
          row.status,
        )
      })
  }
}

fn list_items(
  conn: db.Connection,
  id: BookingId,
) -> Promise(Result(List(BookingItem), RepoError)) {
  use res <- promise.map(queries.list_booking_items(
    conn,
    booking.booking_id(id),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) -> list.try_map(rows, reconstruct_item)
  }
}

fn apply_transition(
  conn: db.Connection,
  b: Booking,
  frees: Bool,
) -> Promise(Result(Nil, RepoError)) {
  let id = booking.booking_id(booking.id(b))
  let status = booking.status_to_string(booking.status(b))
  use res <- promise.map(
    db.transaction(conn, fn(tx) {
      use _ <- promise.try_await(queries.update_booking_status(tx, id, status))
      case frees {
        False -> promise.resolve(Ok(Nil))
        True -> {
          use r <- promise.map(queries.release_booking_demand(tx, id))
          result.replace(r, Nil)
        }
      }
    }),
  )
  result.map_error(res, storage_error)
}

fn assign_item(
  conn: db.Connection,
  item_id: BookingItemId,
  bed: SpaceId,
) -> Promise(Result(Nil, BookingConflict)) {
  use res <- promise.map(queries.assign_booking_item(
    conn,
    booking_item.booking_item_id(item_id),
    space.space_id(bed),
  ))
  case res {
    Ok(_) -> Ok(Nil)
    Error(db.ConstraintViolated(constraint: "booking_demand_no_overlap", ..)) ->
      Error(Unavailable)
    Error(other) -> Error(Storage(storage_error(other)))
  }
}

fn beds_left(
  conn: db.Connection,
  room_type: SpaceId,
  p: Period,
) -> Promise(Result(Int, RepoError)) {
  let rt = space.space_id(room_type)
  use cap <- promise.await(queries.room_type_capacity(conn, rt))
  case cap {
    Error(e) -> promise.resolve(Error(storage_error(e)))
    Ok(c) -> {
      use peak <- promise.map(queries.room_type_peak_demand(
        conn,
        rt,
        period.check_in(p),
        period.check_out(p),
      ))
      case peak {
        Error(e) -> Error(storage_error(e))
        Ok(pk) -> {
          let capacity = one_int(c.rows, fn(r) { r.capacity })
          let demand = one_int(pk.rows, fn(r) { r.peak })
          Ok(int.max(0, capacity - demand))
        }
      }
    }
  }
}

fn find_free_unit(
  conn: db.Connection,
  room_type: SpaceId,
  p: Period,
) -> Promise(Result(Option(SpaceId), RepoError)) {
  use res <- promise.map(queries.find_free_unit_in_room_type(
    conn,
    space.space_id(room_type),
    period.check_in(p),
    period.check_out(p),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [], ..)) -> Ok(None)
    Ok(db.Returned(rows: [row, ..], ..)) ->
      space.new_id(row.id) |> result.map(Some) |> result.map_error(corrupt)
  }
}

fn list_room_types(
  conn: db.Connection,
  org: OrganizationId,
) -> Promise(Result(List(RoomType), RepoError)) {
  use res <- promise.map(queries.list_room_types_by_organization(
    conn,
    organization.organization_id(org),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows:, ..)) ->
      list.try_map(rows, fn(row) {
        use sid <- result.try(space.new_id(row.id) |> result.map_error(corrupt))
        Ok(RoomType(sid, row.name, row.label, row.capacity))
      })
  }
}

fn space_has_active_demand(
  conn: db.Connection,
  sid: SpaceId,
) -> Promise(Result(Bool, RepoError)) {
  use res <- promise.map(queries.space_has_active_demand(
    conn,
    space.space_id(sid),
  ))
  case res {
    Error(e) -> Error(storage_error(e))
    Ok(db.Returned(rows: [row, ..], ..)) -> Ok(row.active == 1)
    Ok(db.Returned(rows: [], ..)) -> Ok(False)
  }
}

// --- reconstruction ---------------------------------------------------------

fn reconstruct_booking(
  id: String,
  org: String,
  guest_id: Option(String),
  status: String,
) -> Result(Booking, RepoError) {
  use bid <- result.try(booking.new_id(id) |> result.map_error(corrupt))
  use oid <- result.try(organization.new_id(org) |> result.map_error(corrupt))
  use gid <- result.try(reconstruct_guest(guest_id))
  use st <- result.try(
    booking.status_from_string(status)
    |> result.replace_error(Corrupt("unknown status: " <> status)),
  )
  Ok(booking.new(bid, oid, gid, st))
}

fn reconstruct_guest(
  raw: Option(String),
) -> Result(Option(GuestId), RepoError) {
  case raw {
    None -> Ok(None)
    Some(value) ->
      guest.new_id(value) |> result.map(Some) |> result.map_error(corrupt)
  }
}

fn reconstruct_item(
  row: queries.ListBookingItemsRow,
) -> Result(BookingItem, RepoError) {
  use iid <- result.try(
    booking_item.new_id(row.id) |> result.map_error(corrupt),
  )
  use bid <- result.try(
    booking.new_id(row.booking_id) |> result.map_error(corrupt),
  )
  use p <- result.try(
    period.new(row.check_in, row.check_out) |> result.map_error(corrupt),
  )
  use target <- result.try(
    space.new_id(row.target_space_id) |> result.map_error(corrupt),
  )
  use assigned <- result.try(reconstruct_assigned(row.assigned_space_id))
  let kind = case row.kind {
    "whole" -> WholeSpace(target)
    _ -> UnitInRoomType(target)
  }
  Ok(booking_item.restore(iid, bid, p, kind, assigned))
}

fn reconstruct_assigned(
  raw: Option(String),
) -> Result(Option(SpaceId), RepoError) {
  case raw {
    None -> Ok(None)
    Some(value) ->
      space.new_id(value) |> result.map(Some) |> result.map_error(corrupt)
  }
}

// --- helpers ----------------------------------------------------------------

/// Build a tagged PostgresqlError used to roll the transaction back with a
/// domain reason the outer `create` mapping can recognise.
fn tagged(name: String, message: String) -> db.SqlError {
  db.PostgresqlError(code: "HZ000", name: name, message: message)
}

fn one_int(rows: List(a), get: fn(a) -> Int) -> Int {
  case rows {
    [row, ..] -> get(row)
    [] -> 0
  }
}

fn corrupt(reason: a) -> RepoError {
  Corrupt(string.inspect(reason))
}

fn storage_error(error: db.SqlError) -> RepoError {
  StorageError(string.inspect(error))
}
