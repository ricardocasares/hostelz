//// Application use case: create an organization and make its creator the Owner.
////
//// Creates the org (slug uniqueness enforced by the DB → `SlugTaken`), then
//// seeds the single system `Owner` role and a membership linking the creator
//// to it. The Owner role implicitly holds every permission. (Several saves; a
//// transaction would be ideal — see the repo note.)

import domain/membership
import domain/membership_repo.{type MembershipRepo}
import domain/organization.{type Organization}
import domain/organization_repo.{type OrganizationRepo}
import domain/repo_error.{type RepoError}
import domain/role
import domain/role_repo.{type RoleRepo}
import domain/slug
import domain/user.{type UserId}
import gleam/javascript/promise.{type Promise}
import gleam/result

pub type CreateOrganizationError {
  InvalidOrganization(organization.OrganizationError)
  InvalidSlug(slug.SlugError)
  SlugTaken
  RepoFailed(RepoError)
}

pub fn run(
  org_repo: OrganizationRepo,
  role_repo: RoleRepo,
  membership_repo: MembershipRepo,
  generate_id: fn() -> String,
  owner: UserId,
  raw_slug: String,
  name: String,
) -> Promise(Result(Organization, CreateOrganizationError)) {
  case build(generate_id(), raw_slug, name) {
    Error(error) -> promise.resolve(Error(error))
    Ok(org) -> {
      use saved <- promise.await(org_repo.save(org))
      case saved {
        Error(repo_error.Conflict(_)) -> promise.resolve(Error(SlugTaken))
        Error(other) -> promise.resolve(Error(RepoFailed(other)))
        Ok(Nil) ->
          seed_owner(role_repo, membership_repo, generate_id, org, owner)
      }
    }
  }
}

fn seed_owner(
  role_repo: RoleRepo,
  membership_repo: MembershipRepo,
  generate_id: fn() -> String,
  org: Organization,
  owner: UserId,
) -> Promise(Result(Organization, CreateOrganizationError)) {
  let assert Ok(role_id) = role.new_id(generate_id())
  let owner_role = role.owner(role_id, organization.id(org))
  use role_saved <- promise.await(role_repo.save(owner_role))
  case role_saved {
    Error(e) -> promise.resolve(Error(RepoFailed(e)))
    Ok(Nil) -> {
      let assert Ok(membership_id) = membership.new_id(generate_id())
      let member =
        membership.new(
          membership_id,
          organization.id(org),
          owner,
          role.id(owner_role),
        )
      use member_saved <- promise.map(membership_repo.save(member))
      case member_saved {
        Ok(Nil) -> Ok(org)
        Error(e) -> Error(RepoFailed(e))
      }
    }
  }
}

fn build(
  id: String,
  raw_slug: String,
  name: String,
) -> Result(Organization, CreateOrganizationError) {
  use oid <- result.try(
    organization.new_id(id) |> result.map_error(InvalidOrganization),
  )
  use org_slug <- result.try(
    slug.new(raw_slug) |> result.map_error(InvalidSlug),
  )
  organization.new(oid, org_slug, name)
  |> result.map_error(InvalidOrganization)
}
