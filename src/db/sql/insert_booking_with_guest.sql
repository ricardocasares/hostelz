-- Insert a booking for a guest.
insert into bookings (id, organization_id, guest_id, status, updated_at)
values ($1, $2, $3, $4, now());
