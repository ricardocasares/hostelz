-- Update a booking's status.
update bookings set status = $2, updated_at = now() where id = $1;
