-- Free a booking's held space when it leaves a blocking status: delete all its
-- demand rows. The booking and its items remain, for history.
delete from booking_demand
where booking_item_id in (
  select id from booking_items where booking_id = $1
);
