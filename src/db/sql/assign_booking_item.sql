-- Assign an unassigned item to a specific bed: delete its hold demand, set the
-- item's assigned space, and pin the bed for the same period. The partial
-- EXCLUDE rejects the pin if the bed is already taken for an overlapping period.
with removed as (
  delete from booking_demand
  where booking_item_id = $1 and is_pin = false
  returning period
),
updated as (
  update booking_items
  set assigned_space_id = $2, updated_at = now()
  where id = $1
)
insert into booking_demand (booking_item_id, space_id, period, is_pin)
select $1, $2, removed.period, true
from removed;
