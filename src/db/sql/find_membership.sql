-- A user's membership in an organization.
select id, organization_id, user_id, role_id
from memberships
where organization_id = $1
  and user_id = $2;
