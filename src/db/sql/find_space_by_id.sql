-- Find a single space by id.
select id, organization_id, parent_id, is_grouping, label, name
from spaces
where id = $1;
