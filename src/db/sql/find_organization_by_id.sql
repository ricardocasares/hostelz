-- Find a single organization by id.
select id, slug, name
from organizations
where id = $1;
