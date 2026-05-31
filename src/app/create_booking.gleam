//// Application use case: create a booking with one or more items.
////
//// Validates the guest (if any) and each item's space against the organization,
//// builds the domain booking, then persists atomically via the repository,
//// which enforces the oversell guard (capacity + pinned exclusivity) under a
//// per-org lock. A whole-space item must target a bookable space; an unassigned
//// hold's room-type validity is checked in the adapter.

import domain/booking.{type Booking, type BookingId}
import domain/booking_item.{type BookingItem}
import domain/booking_repo.{type BookingRepo}
import domain/guest.{type GuestId}
import domain/guest_repo.{type GuestRepo}
import domain/organization.{type OrganizationId}
import domain/period.{type Period}
import domain/repo_error.{type RepoError}
import domain/space.{type SpaceId}
import domain/space_repo.{type SpaceRepo}
import gleam/javascript/promise.{type Promise}
import gleam/option.{type Option, None, Some}

/// One requested item: `kind` is "whole" (pin the space) or "unit" (an
/// unassigned hold against a room-type).
pub type NewItem {
  NewItem(kind: String, space_id: String, check_in: String, check_out: String)
}

pub type CreateBookingError {
  NoItems
  InvalidId
  InvalidPeriod(period.PeriodError)
  InvalidKind(String)
  GuestNotFound
  GuestDifferentOrganization
  SpaceNotFound
  SpaceDifferentOrganization
  NotBookable
  NotARoomType
  OverCapacity
  Unavailable
  RepoFailed(RepoError)
}

pub fn run(
  space_repo: SpaceRepo,
  booking_repo: BookingRepo,
  guest_repo: GuestRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  guest_id: Option(String),
  items: List(NewItem),
) -> Promise(Result(Booking, CreateBookingError)) {
  case items {
    [] -> promise.resolve(Error(NoItems))
    _ -> {
      use checked_guest <- promise.await(check_guest(
        guest_repo,
        organization_id,
        guest_id,
      ))
      case checked_guest {
        Error(e) -> promise.resolve(Error(e))
        Ok(gid) ->
          case booking.new_id(generate_id()) {
            Error(_) -> promise.resolve(Error(InvalidId))
            Ok(bid) -> {
              use built <- promise.await(build_items(
                space_repo,
                generate_id,
                organization_id,
                bid,
                items,
              ))
              case built {
                Error(e) -> promise.resolve(Error(e))
                Ok(domain_items) ->
                  persist(booking_repo, organization_id, gid, bid, domain_items)
              }
            }
          }
      }
    }
  }
}

fn persist(
  booking_repo: BookingRepo,
  organization_id: OrganizationId,
  gid: Option(GuestId),
  bid: BookingId,
  items: List(BookingItem),
) -> Promise(Result(Booking, CreateBookingError)) {
  let bk = booking.new(bid, organization_id, gid, booking.Confirmed)
  use created <- promise.map(booking_repo.create(bk, items))
  case created {
    Ok(Nil) -> Ok(bk)
    Error(booking_repo.Unavailable) -> Error(Unavailable)
    Error(booking_repo.OverCapacity(_)) -> Error(OverCapacity)
    Error(booking_repo.NotARoomType(_)) -> Error(NotARoomType)
    Error(booking_repo.Storage(e)) -> Error(RepoFailed(e))
  }
}

fn check_guest(
  guest_repo: GuestRepo,
  organization_id: OrganizationId,
  guest_id: Option(String),
) -> Promise(Result(Option(GuestId), CreateBookingError)) {
  case guest_id {
    None -> promise.resolve(Ok(None))
    Some(raw) ->
      case guest.new_id(raw) {
        Error(_) -> promise.resolve(Error(InvalidId))
        Ok(gid) -> {
          use found <- promise.map(guest_repo.find(gid))
          case found {
            Error(repo_error.NotFound) -> Error(GuestNotFound)
            Error(other) -> Error(RepoFailed(other))
            Ok(g) ->
              case guest.organization_id(g) == organization_id {
                False -> Error(GuestDifferentOrganization)
                True -> Ok(Some(gid))
              }
          }
        }
      }
  }
}

fn build_items(
  space_repo: SpaceRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  bid: BookingId,
  items: List(NewItem),
) -> Promise(Result(List(BookingItem), CreateBookingError)) {
  case items {
    [] -> promise.resolve(Ok([]))
    [item, ..rest] -> {
      use first <- promise.await(build_item(
        space_repo,
        generate_id,
        organization_id,
        bid,
        item,
      ))
      case first {
        Error(e) -> promise.resolve(Error(e))
        Ok(bi) -> {
          use more <- promise.map(build_items(
            space_repo,
            generate_id,
            organization_id,
            bid,
            rest,
          ))
          case more {
            Error(e) -> Error(e)
            Ok(rest_items) -> Ok([bi, ..rest_items])
          }
        }
      }
    }
  }
}

fn build_item(
  space_repo: SpaceRepo,
  generate_id: fn() -> String,
  organization_id: OrganizationId,
  bid: BookingId,
  item: NewItem,
) -> Promise(Result(BookingItem, CreateBookingError)) {
  case period.new(item.check_in, item.check_out), space.new_id(item.space_id) {
    Error(e), _ -> promise.resolve(Error(InvalidPeriod(e)))
    _, Error(_) -> promise.resolve(Error(InvalidId))
    Ok(p), Ok(sid) -> {
      use found <- promise.map(space_repo.find(sid))
      case found {
        Error(repo_error.NotFound) -> Error(SpaceNotFound)
        Error(other) -> Error(RepoFailed(other))
        Ok(sp) ->
          case space.organization_id(sp) == organization_id {
            False -> Error(SpaceDifferentOrganization)
            True -> finish_item(generate_id, bid, p, sid, sp, item.kind)
          }
      }
    }
  }
}

fn finish_item(
  generate_id: fn() -> String,
  bid: BookingId,
  p: Period,
  sid: SpaceId,
  sp: space.Space,
  kind: String,
) -> Result(BookingItem, CreateBookingError) {
  case booking_item.new_id(generate_id()) {
    Error(_) -> Error(InvalidId)
    Ok(iid) ->
      case kind {
        "whole" ->
          case space.is_bookable(sp) {
            False -> Error(NotBookable)
            True -> Ok(booking_item.whole(iid, bid, p, sid))
          }
        "unit" -> Ok(booking_item.unit_in(iid, bid, p, sid))
        other -> Error(InvalidKind(other))
      }
  }
}
