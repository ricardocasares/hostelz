-- An organization's role rows, oldest first.
select id, organization_id, name, is_owner
from roles
where organization_id = $1
order by created_at asc;
