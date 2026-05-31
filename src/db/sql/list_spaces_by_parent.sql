-- List the direct children of a space, oldest first.
select id, organization_id, parent_id, is_grouping, label, name
from spaces
where parent_id = $1
order by created_at asc;
