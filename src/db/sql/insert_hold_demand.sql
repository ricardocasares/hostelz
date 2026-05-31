-- Materialize an unassigned hold: a single demand row on the room-type.
insert into booking_demand (booking_item_id, space_id, period, is_pin)
values ($1, $2, daterange($3, $4, '[)'), false);
