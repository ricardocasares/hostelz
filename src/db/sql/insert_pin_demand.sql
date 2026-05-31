-- Materialize an assigned item's demand: the booked node plus all its
-- descendants, as pinned rows. The partial EXCLUDE rejects any overlapping pin
-- on the same node.
with recursive subtree (id) as (
  select id from spaces where id = $2
  union all
  select s.id from spaces s join subtree t on s.parent_id = t.id
)
insert into booking_demand (booking_item_id, space_id, period, is_pin)
select $1, subtree.id, daterange($3, $4, '[)'), true
from subtree;
