-- Insert a booking item pinned to a specific space (a bed, or a whole grouping).
insert into booking_items
  (id, booking_id, period, kind, target_space_id, assigned_space_id, updated_at)
values ($1, $2, daterange($3, $4, '[)'), $5, $6, $7, now());
