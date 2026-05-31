-- Find a single organization by its slug.
select id, slug, name
from organizations
where slug = $1;
