//// Application use case: assign a physical bed to an unassigned hold (at
//// check-in). Picks a free bed in the item's room-type unless one is supplied;
//// the capacity guard guarantees a free bed exists, and the adapter's pin
//// rejects a racing double-assignment.

import domain/booking
import domain/booking_item.{type BookingItem, type BookingItemId, UnitInRoomType}
import domain/booking_repo.{type BookingRepo}
import domain/repo_error.{type RepoError}
import domain/space.{type SpaceId}
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type AssignItemError {
  InvalidId
  ItemNotFound
  AlreadyAssigned
  NotDeferred
  NoFreeUnit
  Unavailable
  RepoFailed(RepoError)
}

pub fn run(
  repo: BookingRepo,
  raw_booking_id: String,
  raw_item_id: String,
  bed: Option(String),
) -> Promise(Result(BookingItem, AssignItemError)) {
  case booking.new_id(raw_booking_id), booking_item.new_id(raw_item_id) {
    Ok(bid), Ok(iid) -> {
      use items <- promise.await(repo.list_items(bid))
      case items {
        Error(e) -> promise.resolve(Error(RepoFailed(e)))
        Ok(list) ->
          case find_item(list, iid) {
            Error(Nil) -> promise.resolve(Error(ItemNotFound))
            Ok(item) -> assign(repo, item, bed)
          }
      }
    }
    _, _ -> promise.resolve(Error(InvalidId))
  }
}

fn find_item(
  items: List(BookingItem),
  iid: BookingItemId,
) -> Result(BookingItem, Nil) {
  list.find(items, fn(item) { booking_item.id(item) == iid })
}

fn assign(
  repo: BookingRepo,
  item: BookingItem,
  bed: Option(String),
) -> Promise(Result(BookingItem, AssignItemError)) {
  case booking_item.kind(item), booking_item.assigned(item) {
    _, Some(_) -> promise.resolve(Error(AlreadyAssigned))
    UnitInRoomType(room_type), None -> resolve_bed(repo, item, room_type, bed)
    _, None -> promise.resolve(Error(NotDeferred))
  }
}

fn resolve_bed(
  repo: BookingRepo,
  item: BookingItem,
  room_type: SpaceId,
  bed: Option(String),
) -> Promise(Result(BookingItem, AssignItemError)) {
  case bed {
    Some(raw) ->
      case space.new_id(raw) {
        Error(_) -> promise.resolve(Error(InvalidId))
        Ok(chosen) -> do_assign(repo, item, chosen)
      }
    None -> {
      use free <- promise.await(repo.find_free_unit(
        room_type,
        booking_item.period(item),
      ))
      case free {
        Error(e) -> promise.resolve(Error(RepoFailed(e)))
        Ok(None) -> promise.resolve(Error(NoFreeUnit))
        Ok(Some(chosen)) -> do_assign(repo, item, chosen)
      }
    }
  }
}

fn do_assign(
  repo: BookingRepo,
  item: BookingItem,
  bed: SpaceId,
) -> Promise(Result(BookingItem, AssignItemError)) {
  use res <- promise.map(repo.assign_item(booking_item.id(item), bed))
  case res {
    Ok(Nil) ->
      case booking_item.assign(item, bed) {
        Ok(updated) -> Ok(updated)
        Error(_) -> Error(AlreadyAssigned)
      }
    Error(booking_repo.Storage(e)) -> Error(RepoFailed(e))
    Error(_) -> Error(Unavailable)
  }
}
