-- Whether any active booking demand falls within a space's subtree (used to
-- block reparenting a space that has live bookings).
with recursive subtree (id) as (
  select id from spaces where id = $1
  union all
  select s.id from spaces s join subtree t on s.parent_id = t.id
)
select (exists (
  select 1 from booking_demand d
  join subtree t on t.id = d.space_id
))::int as active;
