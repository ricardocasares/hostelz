-- List all organizations, most recently created first.
select id, slug, name
from organizations
order by created_at desc;
