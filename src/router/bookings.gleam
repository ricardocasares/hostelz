//// The bookings HTTP handlers. Bookings are nested under their organization and
//// gated by `booking:*` permissions; show/transition/assign resolve the booking
//// then check the permission on its organization. Availability is read-only and
//// keyed by room-type.

import app/assign_booking_item
import app/check_availability
import app/create_booking
import app/find_booking
import app/list_available_room_types
import app/list_organization_bookings
import app/transition_booking
import conversation.{type RequestBody, type ResponseBody}
import db/booking_repo
import db/guest_repo
import db/space_repo
import domain/booking.{type Booking}
import domain/booking_item.{type BookingItem}
import domain/guest
import domain/organization
import domain/period
import domain/permission
import domain/space
import domain/user.{type User}
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import router/context.{type Deps}
import router/guard
import router/reply

type NewBooking {
  NewBooking(guest_id: Option(String), items: List(create_booking.NewItem))
}

pub fn list(
  deps: Deps,
  user: User,
  org_id: String,
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(
    deps,
    user,
    org_id,
    permission.BookingRead,
  )
  let repo = booking_repo.new(deps.db)
  use result <- promise.map(list_organization_bookings.run(repo, oid))
  case result {
    Ok(bookings) ->
      reply.json_response(200, json.array(bookings, booking_to_json))
    Error(list_organization_bookings.RepoFailed(_)) ->
      reply.json_response(500, error_json("could not list bookings"))
  }
}

pub fn create(
  deps: Deps,
  user: User,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(
    deps,
    user,
    org_id,
    permission.BookingCreate,
  )
  use payload <- promise.await(conversation.read_json(req.body))
  case payload {
    Error(_) ->
      promise.resolve(reply.json_response(400, error_json("invalid JSON")))
    Ok(data) ->
      case decode.run(data, new_booking_decoder()) {
        Error(_) ->
          promise.resolve(reply.json_response(
            422,
            error_json(
              "expected \"items\" with kind/space_id/check_in/check_out",
            ),
          ))
        Ok(input) -> {
          use result <- promise.map(create_booking.run(
            space_repo.new(deps.db),
            booking_repo.new(deps.db),
            guest_repo.new(deps.db),
            deps.generate_id,
            oid,
            input.guest_id,
            input.items,
          ))
          case result {
            Ok(bk) -> reply.json_response(201, booking_to_json(bk))
            Error(create_booking.NoItems) ->
              reply.json_response(
                422,
                error_json("at least one item is required"),
              )
            Error(create_booking.Unavailable) ->
              reply.json_response(
                409,
                error_json("a space is unavailable for those dates"),
              )
            Error(create_booking.OverCapacity) ->
              reply.json_response(
                409,
                error_json("no capacity for those dates"),
              )
            Error(create_booking.NotARoomType) ->
              reply.json_response(
                422,
                error_json("space is not a bookable room-type"),
              )
            Error(create_booking.NotBookable) ->
              reply.json_response(422, error_json("space is not bookable"))
            Error(create_booking.SpaceNotFound)
            | Error(create_booking.SpaceDifferentOrganization) ->
              reply.json_response(404, error_json("space not found"))
            Error(create_booking.GuestNotFound)
            | Error(create_booking.GuestDifferentOrganization) ->
              reply.json_response(404, error_json("guest not found"))
            Error(create_booking.InvalidKind(_)) ->
              reply.json_response(
                422,
                error_json("item kind must be \"whole\" or \"unit\""),
              )
            Error(create_booking.InvalidPeriod(_)) ->
              reply.json_response(
                422,
                error_json("invalid check-in/check-out dates"),
              )
            Error(create_booking.InvalidId) ->
              reply.json_response(422, error_json("invalid id"))
            Error(create_booking.RepoFailed(_)) ->
              reply.json_response(500, error_json("could not create booking"))
          }
        }
      }
  }
}

pub fn show(
  deps: Deps,
  user: User,
  id: String,
) -> Promise(Response(ResponseBody)) {
  let repo = booking_repo.new(deps.db)
  use found <- promise.await(find_booking.run(repo, id))
  case found {
    Error(find_booking.NotFound) | Error(find_booking.InvalidId) ->
      promise.resolve(reply.json_response(404, error_json("booking not found")))
    Error(find_booking.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load booking"),
      ))
    Ok(#(bk, items)) -> {
      use <- guard.require_permission_for_org(
        deps,
        user,
        booking.organization_id(bk),
        permission.BookingRead,
      )
      promise.resolve(reply.json_response(200, booking_detail_json(bk, items)))
    }
  }
}

pub fn transition(
  deps: Deps,
  user: User,
  id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  let repo = booking_repo.new(deps.db)
  use found <- promise.await(find_booking.run(repo, id))
  case found {
    Error(find_booking.NotFound) | Error(find_booking.InvalidId) ->
      promise.resolve(reply.json_response(404, error_json("booking not found")))
    Error(find_booking.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load booking"),
      ))
    Ok(#(bk, _)) -> {
      use <- guard.require_permission_for_org(
        deps,
        user,
        booking.organization_id(bk),
        permission.BookingUpdate,
      )
      use payload <- promise.await(conversation.read_json(req.body))
      case payload {
        Error(_) ->
          promise.resolve(reply.json_response(400, error_json("invalid JSON")))
        Ok(data) ->
          case decode.run(data, status_decoder()) {
            Error(_) ->
              promise.resolve(reply.json_response(
                422,
                error_json("expected a \"status\" string"),
              ))
            Ok(status) ->
              case to_transition(status) {
                Error(Nil) ->
                  promise.resolve(reply.json_response(
                    422,
                    error_json("unknown target status"),
                  ))
                Ok(transition) -> {
                  use result <- promise.map(transition_booking.run(
                    repo,
                    id,
                    transition,
                  ))
                  case result {
                    Ok(updated) ->
                      reply.json_response(200, booking_to_json(updated))
                    Error(transition_booking.InvalidTransition) ->
                      reply.json_response(
                        409,
                        error_json("invalid status transition"),
                      )
                    Error(transition_booking.NotFound)
                    | Error(transition_booking.InvalidId) ->
                      reply.json_response(404, error_json("booking not found"))
                    Error(transition_booking.RepoFailed(_)) ->
                      reply.json_response(
                        500,
                        error_json("could not update booking"),
                      )
                  }
                }
              }
          }
      }
    }
  }
}

pub fn assign(
  deps: Deps,
  user: User,
  booking_id: String,
  item_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  let repo = booking_repo.new(deps.db)
  use found <- promise.await(find_booking.run(repo, booking_id))
  case found {
    Error(find_booking.NotFound) | Error(find_booking.InvalidId) ->
      promise.resolve(reply.json_response(404, error_json("booking not found")))
    Error(find_booking.RepoFailed(_)) ->
      promise.resolve(reply.json_response(
        500,
        error_json("could not load booking"),
      ))
    Ok(#(bk, _)) -> {
      use <- guard.require_permission_for_org(
        deps,
        user,
        booking.organization_id(bk),
        permission.BookingUpdate,
      )
      use payload <- promise.await(conversation.read_json(req.body))
      let bed = case payload {
        Ok(data) ->
          case decode.run(data, optional_space_decoder()) {
            Ok(value) -> value
            Error(_) -> None
          }
        Error(_) -> None
      }
      use result <- promise.map(assign_booking_item.run(
        repo,
        booking_id,
        item_id,
        bed,
      ))
      case result {
        Ok(item) -> reply.json_response(200, item_to_json(item))
        Error(assign_booking_item.ItemNotFound) ->
          reply.json_response(404, error_json("booking item not found"))
        Error(assign_booking_item.AlreadyAssigned) ->
          reply.json_response(409, error_json("item is already assigned"))
        Error(assign_booking_item.NotDeferred) ->
          reply.json_response(422, error_json("item is not an unassigned hold"))
        Error(assign_booking_item.NoFreeUnit) ->
          reply.json_response(409, error_json("no free bed to assign"))
        Error(assign_booking_item.Unavailable) ->
          reply.json_response(409, error_json("bed is unavailable"))
        Error(assign_booking_item.InvalidId) ->
          reply.json_response(404, error_json("not found"))
        Error(assign_booking_item.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not assign bed"))
      }
    }
  }
}

pub fn available_room_types(
  deps: Deps,
  user: User,
  org_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use oid <- guard.require_permission(
    deps,
    user,
    org_id,
    permission.BookingRead,
  )
  case query_dates(req) {
    Error(Nil) ->
      promise.resolve(reply.json_response(
        422,
        error_json("\"from\" and \"to\" query params are required"),
      ))
    Ok(#(from, to)) -> {
      let repo = booking_repo.new(deps.db)
      use result <- promise.map(list_available_room_types.run(
        repo,
        oid,
        from,
        to,
      ))
      case result {
        Ok(available) ->
          reply.json_response(200, json.array(available, available_to_json))
        Error(list_available_room_types.InvalidPeriod(_)) ->
          reply.json_response(422, error_json("invalid dates"))
        Error(list_available_room_types.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not list availability"))
      }
    }
  }
}

pub fn room_type_availability(
  deps: Deps,
  user: User,
  org_id: String,
  room_type_id: String,
  req: Request(RequestBody),
) -> Promise(Response(ResponseBody)) {
  use _ <- guard.require_permission(deps, user, org_id, permission.BookingRead)
  case query_dates(req) {
    Error(Nil) ->
      promise.resolve(reply.json_response(
        422,
        error_json("\"from\" and \"to\" query params are required"),
      ))
    Ok(#(from, to)) -> {
      let repo = booking_repo.new(deps.db)
      use result <- promise.map(check_availability.run(
        repo,
        room_type_id,
        from,
        to,
      ))
      case result {
        Ok(beds_left) ->
          reply.json_response(
            200,
            json.object([#("beds_left", json.int(beds_left))]),
          )
        Error(check_availability.InvalidId) ->
          reply.json_response(404, error_json("room-type not found"))
        Error(check_availability.InvalidPeriod(_)) ->
          reply.json_response(422, error_json("invalid dates"))
        Error(check_availability.RepoFailed(_)) ->
          reply.json_response(500, error_json("could not check availability"))
      }
    }
  }
}

// --- decoders ---------------------------------------------------------------

fn new_booking_decoder() -> decode.Decoder(NewBooking) {
  use guest_id <- decode.optional_field(
    "guest_id",
    None,
    decode.optional(decode.string),
  )
  use items <- decode.field("items", decode.list(item_decoder()))
  decode.success(NewBooking(guest_id:, items:))
}

fn item_decoder() -> decode.Decoder(create_booking.NewItem) {
  use kind <- decode.field("kind", decode.string)
  use space_id <- decode.field("space_id", decode.string)
  use check_in <- decode.field("check_in", decode.string)
  use check_out <- decode.field("check_out", decode.string)
  decode.success(create_booking.NewItem(kind:, space_id:, check_in:, check_out:))
}

fn status_decoder() -> decode.Decoder(String) {
  use status <- decode.field("status", decode.string)
  decode.success(status)
}

fn optional_space_decoder() -> decode.Decoder(Option(String)) {
  use space_id <- decode.optional_field(
    "space_id",
    None,
    decode.optional(decode.string),
  )
  decode.success(space_id)
}

fn to_transition(status: String) -> Result(transition_booking.Transition, Nil) {
  case status {
    "confirmed" -> Ok(transition_booking.Confirm)
    "checked_in" -> Ok(transition_booking.CheckIn)
    "checked_out" -> Ok(transition_booking.CheckOut)
    "cancelled" -> Ok(transition_booking.Cancel)
    "no_show" -> Ok(transition_booking.NoShow)
    _ -> Error(Nil)
  }
}

fn query_dates(req: Request(RequestBody)) -> Result(#(String, String), Nil) {
  let params = request.get_query(req) |> result.unwrap([])
  use from <- result.try(list.key_find(params, "from"))
  use to <- result.try(list.key_find(params, "to"))
  Ok(#(from, to))
}

// --- json -------------------------------------------------------------------

fn booking_to_json(bk: Booking) -> json.Json {
  json.object([
    #("id", json.string(booking.booking_id(booking.id(bk)))),
    #(
      "organization_id",
      json.string(organization.organization_id(booking.organization_id(bk))),
    ),
    #(
      "guest_id",
      json.nullable(booking.guest_id(bk), fn(g) {
        json.string(guest.guest_id(g))
      }),
    ),
    #("status", json.string(booking.status_to_string(booking.status(bk)))),
  ])
}

fn booking_detail_json(bk: Booking, items: List(BookingItem)) -> json.Json {
  json.object([
    #("id", json.string(booking.booking_id(booking.id(bk)))),
    #(
      "organization_id",
      json.string(organization.organization_id(booking.organization_id(bk))),
    ),
    #(
      "guest_id",
      json.nullable(booking.guest_id(bk), fn(g) {
        json.string(guest.guest_id(g))
      }),
    ),
    #("status", json.string(booking.status_to_string(booking.status(bk)))),
    #("items", json.array(items, item_to_json)),
  ])
}

fn item_to_json(item: BookingItem) -> json.Json {
  let p = booking_item.period(item)
  json.object([
    #("id", json.string(booking_item.booking_item_id(booking_item.id(item)))),
    #("kind", json.string(booking_item.kind_to_string(booking_item.kind(item)))),
    #("target_space_id", json.string(space.space_id(booking_item.target(item)))),
    #(
      "assigned_space_id",
      json.nullable(booking_item.assigned(item), fn(s) {
        json.string(space.space_id(s))
      }),
    ),
    #("check_in", json.string(period.check_in_iso(p))),
    #("check_out", json.string(period.check_out_iso(p))),
  ])
}

fn available_to_json(
  available: list_available_room_types.AvailableRoomType,
) -> json.Json {
  let rt = available.room_type
  json.object([
    #("id", json.string(space.space_id(rt.id))),
    #("name", json.string(rt.name)),
    #("label", json.string(rt.label)),
    #("capacity", json.int(rt.capacity)),
    #("beds_left", json.int(available.beds_left)),
  ])
}

fn error_json(message: String) -> json.Json {
  json.object([#("error", json.string(message))])
}
