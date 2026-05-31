-- The room-types whose capacity an item consumes: the parents of the bookable
-- leaf nodes it pins, plus the room-type a hold targets.
select room_type
from (
  select distinct s.parent_id as room_type
  from booking_demand d
  join spaces s on s.id = d.space_id
  where d.booking_item_id = $1 and d.is_pin = true and s.is_grouping = false
  union
  select d.space_id as room_type
  from booking_demand d
  where d.booking_item_id = $1 and d.is_pin = false
) t
where room_type is not null;
