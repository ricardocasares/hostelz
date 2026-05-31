-- List one organization's spaces, oldest first (so parents tend to precede
-- their children when assembling the tree).
select id, organization_id, parent_id, is_grouping, label, name
from spaces
where organization_id = $1
order by created_at asc;
