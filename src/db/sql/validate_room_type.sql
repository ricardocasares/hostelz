-- Whether a space is a one-level room-type: a grouping with no grouping children
-- and at least one bookable leaf child.
select (
  exists (select 1 from spaces where id = $1 and is_grouping = true)
  and not exists (
    select 1 from spaces c where c.parent_id = $1 and c.is_grouping = true
  )
  and exists (
    select 1 from spaces c
    where c.parent_id = $1 and c.is_grouping = false and c.bookable = true
  )
)::int as valid;
