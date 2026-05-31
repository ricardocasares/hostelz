-- Find a single guest by id.
select id, organization_id, user_id, name, email
from guests
where id = $1;
