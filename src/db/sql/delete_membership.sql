-- Remove a user from an organization.
delete from memberships
where organization_id = $1
  and user_id = $2;
