-- A bookable leaf child of the room-type with no overlapping pin over the
-- period — a free physical bed to assign at check-in.
select leaf.id
from spaces leaf
where leaf.parent_id = $1 and leaf.is_grouping = false and leaf.bookable = true
  and not exists (
    select 1 from booking_demand d
    where d.is_pin and d.space_id = leaf.id
      and d.period && daterange($2, $3, '[)')
  )
order by leaf.created_at asc
limit 1;
