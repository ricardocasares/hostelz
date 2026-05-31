-- Peak concurrent demand on a room-type over [check_in, check_out): the max,
-- across the period's candidate dates, of pinned bookable leaf children plus
-- unassigned holds on the room-type that cover that date.
with demand as (
  select dd.period
  from spaces leaf
  join booking_demand dd on dd.is_pin and dd.space_id = leaf.id
  where leaf.parent_id = $1 and leaf.is_grouping = false and leaf.bookable = true
  union all
  select period
  from booking_demand
  where is_pin = false and space_id = $1
),
candidates as (
  select lower(period) as d from demand
  where lower(period) >= $2 and lower(period) < $3
  union
  select $2
)
select coalesce(
  max((select count(*) from demand x where x.period @> c.d)),
  0
)::int as peak
from candidates c;
