//// Application use case: find an organization by id. Read-only counterpart to
//// `create_organization`; a "no such org" repo failure is lifted to its own
//// `NotFound` variant so the HTTP boundary can answer 404.

import domain/organization.{type Organization}
import domain/organization_repo.{type OrganizationRepo}
import domain/repo_error.{type RepoError}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type FindOrganizationError {
  InvalidId(organization.OrganizationError)
  NotFound
  RepoFailed(RepoError)
}

pub fn run(
  repo: OrganizationRepo,
  raw_id: String,
) -> Promise(Result(Organization, FindOrganizationError)) {
  case organization.new_id(raw_id) {
    Error(error) -> promise.resolve(Error(InvalidId(error)))
    Ok(id) -> {
      use result <- promise.map(repo.find(id))
      result |> result.map_error(to_error)
    }
  }
}

fn to_error(error: RepoError) -> FindOrganizationError {
  case error {
    repo_error.NotFound -> NotFound
    other -> RepoFailed(other)
  }
}
