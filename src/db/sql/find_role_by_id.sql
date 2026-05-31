-- A single role row (permissions fetched separately).
select id, organization_id, name, is_owner
from roles
where id = $1;
