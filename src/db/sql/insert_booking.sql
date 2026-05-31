-- Insert a booking with no guest (a maintenance/blocking hold).
insert into bookings (id, organization_id, status, updated_at)
values ($1, $2, $3, now());
