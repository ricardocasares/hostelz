-- One-level room-types in an organization: groupings with no grouping children
-- and at least one bookable leaf child, with their bookable capacity.
select g.id, g.name, g.label,
  (
    select count(*) from spaces leaf
    where leaf.parent_id = g.id and leaf.is_grouping = false and leaf.bookable = true
  )::int as capacity
from spaces g
where g.organization_id = $1 and g.is_grouping = true
  and not exists (
    select 1 from spaces c where c.parent_id = g.id and c.is_grouping = true
  )
  and exists (
    select 1 from spaces c
    where c.parent_id = g.id and c.is_grouping = false and c.bookable = true
  )
order by g.created_at asc;
