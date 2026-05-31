//// Application use case: list an organization's bookings.

import domain/booking.{type Booking}
import domain/booking_repo.{type BookingRepo}
import domain/organization.{type OrganizationId}
import domain/repo_error.{type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type ListBookingsError {
  RepoFailed(RepoError)
}

pub fn run(
  repo: BookingRepo,
  organization_id: OrganizationId,
) -> Promise(Result(List(Booking), ListBookingsError)) {
  use res <- promise.map(repo.list_by_organization(organization_id))
  result.map_error(res, RepoFailed)
}
