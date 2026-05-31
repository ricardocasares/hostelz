-- Bookable capacity of a one-level room-type: its bookable leaf children.
select count(*)::int as capacity
from spaces
where parent_id = $1 and is_grouping = false and bookable = true;
