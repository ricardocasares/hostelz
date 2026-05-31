-- Insert an unassigned booking item (a hold against a one-level room-type).
insert into booking_items
  (id, booking_id, period, kind, target_space_id, updated_at)
values ($1, $2, daterange($3, $4, '[)'), $5, $6, now());
