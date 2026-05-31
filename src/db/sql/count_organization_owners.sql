-- How many members of an organization hold an owner role (for the last-owner
-- guard). Cast to int so it decodes as a plain integer.
select count(*)::int as owners
from memberships m
join roles r on r.id = m.role_id
where m.organization_id = $1
  and r.is_owner = true;
